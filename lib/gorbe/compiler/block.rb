require 'set'

module Gorbe
  module Compiler

    NON_WORD_REGEX = Regexp.new('[^A-Za-z0-9_]')

    class Loop
      attr_reader :break_var

      def initialize(break_var)
        @break_var = break_var
      end

    end

    # A class which stands Ruby block
    class Block
      attr_reader :root
      attr_reader :parent
      attr_reader :name
      attr_reader :free_temps
      attr_reader :used_temps
      attr_reader :temp_index
      attr_reader :label_count
      attr_reader :checkpoints
      attr_reader :loop_stack

      def initialize(parent=nil, name=nil)
        @root = parent ? parent.root : self
        @parent = parent
        @name = name
        @free_temps = Set.new
        @used_temps = Set.new
        @temp_index = 0
        @label_count = 0
        @checkpoints = []
        @loop_stack = []
        # @is_generator
      end

      def bind_var(writer, name, value)
      end

      def gen_label(is_checkpoint=false)
        @label_count += 1
        if is_checkpoint
          @checkpoints.push(@label_count)
        end
        return @label_count
      end

      def alloc_temp(type='*πg.Object')
        @free_temps.sort { |v1, v2| v1.name <=> v2.name } .each do |v|
          if v.type == type
            @free_temps.delete(v)
            @used_temps.add(v)
            return v
          end
        end
        @temp_index += 1
        name = "πTemp%03d" % @temp_index
        v = TempVar.new(block: self, name: name, type: type)
        @used_temps.add(v)
        return v
      end

      def free_temp(v)
        @used_temps.delete(v)
        @free_temps.add(v)
      end

      def push_loop(break_var)
        loop = Loop.new(break_var)
        @loop_stack.push(loop)
        return loop
      end

      def pop_loop()
        @loop_stack.pop
      end

      private def resolve_global(writer, name)
        result = alloc_temp
        writer.write_checked_call2(
            result, "πg.ResolveGlobal(πF, %s)" % @root.intern(name))
        return result
      end
    end

    # A class which stands Ruby top level block
    class TopLevelBlock < Block
      attr_reader :strings

      def initialize
        super(nil, '<toplevel>')
        @strings = Set.new
      end

      def bind_var(writer, name, value)
        # TODO : Change it to call write_checked_call2() instead as assignment returns value in Ruby
        writer.write_checked_call1("πF.Globals().SetItem(πF, #{intern(name)}.ToObject(), #{value})")
      end

      def intern(s)
        if s.length > 64 or NON_WORD_REGEX.match(s)
          return "πg.NewStr(%s)" % Util::generate_go_string(s)
        end
        @strings.add(s)
        return 'ß' + s
      end

      def resolve_name(writer, name)
        return resolve_global(writer, name)
      end

    end


    # A class which stands Ruby function block
    class FunctionBlock < Block
      attr_reader :vars

      def initialize(parent, name, block_vars)
        super(parent, name)
        @vars = block_vars
        @parent = parent
        # @is_generator = is_generator
      end

      def bind_var(writer, name, value)
        if @vars[name].type == Var::TYPE_GLOBAL
          return @root.bind_var(writer, name, value)
        end
        writer.write("#{Util::get_go_identifier(name)} = #{value}")
      end

      def resolve_name(writer, name)
        block = self
        until block.is_a?(TopLevelBlock)
          if block.is_a?(FunctionBlock)
            var = block.vars[name]
            if not var.nil?
              if var.type == Var::TYPE_GLOBAL
                return resolve_global(writer, name)
              end
              writer.write_checked_call1(
                  "πg.CheckLocal(πF, #{Util::get_go_identifier(name)}, #{Util::generate_go_string(name)})")
              return LocalVar.new(name)
            end
          end
          block = block.parent
        end
        return resolve_global(writer, name)
      end
    end


    # A class which stands Ruby variable used within a particular block.
    class Var
      attr_reader :name
      attr_reader :type
      attr_reader :init_expr

      TYPE_LOCAL = 0
      TYPE_PARAM = 1
      TYPE_GLOBAL = 2

      def initialize(name, var_type, arg_index=nil)
        @name = name
        @type = var_type
        if var_type == TYPE_LOCAL
          raise CompileError(node, msg: "Local variables should'nt have arg_index: #{arg_index}.") if not arg_index.nil?
          @init_expr = 'πg.UnboundLocal'
        elsif var_type == TYPE_PARAM
          raise CompileError(node, msg: "Arguments should have arg_index.") if arg_index.nil?
          @init_expr = "πArgs[#{arg_index}]"
        else
          raise CompileError(node, msg: "Global variables should'nt have arg_index.") if not arg_index.nil?
          @init_expr = None
        end
      end
    end

    # A class which visits Ruby AST in a block to determine block variables.
    class BlockVisitor < Visitor

      def initialize(nodetype_map: {}, node: nil)
        nodetype_map[:assign] = 'assign'
        nodetype_map[:def] = 'def'
        super(nodetype_map: nodetype_map)
        @vars = {}
      end

      def visit_assign(node)
        # for target in node.targets:
        #   @assign_target(target)
        # end
        visit(node.value)
      end

      def visit_def(node)
      end

      def visit_paren(node)
      end

      # def _assign_target(self, target):
      #   if isinstance(target, ast.Name):
      #     self._register_local(target.id)
      #   elif isinstance(target, (ast.Tuple, ast.List)):
      #     for elt in target.elts:
      #       self._assign_target(elt)

      # def _register_global(self, node, name):
      #   var = self.vars.get(name)
      #   if var:
      #     if var.type == Var.TYPE_PARAM:
      #       msg = "name '{}' is parameter and global"
      #       raise util.ParseError(node, msg.format(name))
      #     if var.type == Var.TYPE_LOCAL:
      #       msg = "name '{}' is used prior to global declaration"
      #       raise util.ParseError(node, msg.format(name))
      #   else:
      #     self.vars[name] = Var(name, Var.TYPE_GLOBAL)
      #
      # def _register_local(self, name):
      #   if not self.vars.get(name):
      #     self.vars[name] = Var(name, Var.TYPE_LOCAL)
    end

    # A class which visits Ruby AST in a function to determine variables and generator state.
    class FunctionBlockVisitor < BlockVisitor

      attr_reader :vars
      # attr_reader :is_generator

      def initialize(node: nil)
        super(nodetype_map:
            {
                paren: 'paren',
                params: 'params',
                '@ident': 'ident',
                bodystmt: 'bodystmt'
            }
        )
        # @is_generator = false
        node_args = visit(node[2])
        args = node_args[:args]

        # TODO : If there is any vargs or kwargs...
        #   if node_args.vararg:
        #     args.append(node_args.vararg.arg)
        #   if node_args.kwarg:
        #     args.append(node_args.kwarg.arg)

        args.each_with_index do |name, i|
          raise CompileError.new(node, msg: 'Duplicate arguments are used in the same function.') if @vars.include?(name)
          @vars[name] = Var.new(name, Var::TYPE_PARAM, arg_index=i)
        end
      end

      def visit_paren(node)
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        return visit(node[1])
      end

      def visit_params(node)
        raise CompileError.new(node, msg: 'Node must be array.') unless node.is_a?(Array)

        return { args: visit(node[1]) }
      end

      # e.g. [:@ident, "foo", [1, 0]]
      def visit_ident(node)
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        return node[1]
      end

      def visit_bodystmt(node)
        raise CompileError.new(node, msg: 'Node size must be 5.') unless node.length == 5

        return visit(node[1])
      end

      def visit_general(node)
      end
    end

  end
end

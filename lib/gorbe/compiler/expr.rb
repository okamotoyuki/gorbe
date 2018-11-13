module Gorbe
  module Compiler

    # A class which stands an expression in generated Go code.
    class Expr
      attr_reader :name
      attr_reader :type
      attr_reader :expr

      def initialize(block: nil, name: '', type: nil, expr: nil)
        @block = block
        @name = name
        @type = type
        @expr = expr
      end

      def free
      end
    end

    # A class which stands an expression result stored in a temporary value.
    class TempVar < Expr
      def initialize(block: nil, name: '', type: nil)
        super(block: block, name: name, type: type, expr: name)
      end

      def free
        @block.free_temp(self)
      end
    end

    # A class which stands Go local var corresponding to a Python local.
    class LocalVar < Expr
      def initialize(name='')
        super(name: name, expr: Util::get_go_identifier(name))
      end
    end

    # A class which stands a literal in generated Go code.
    class Literal < Expr
      def initialize(expr=nil)
        super(expr: expr)
      end

    end

    NIL_EXPR = Literal.new('nil')

    # A class which generates Go code based on Ruby AST (Expression).
    class ExprVisitor < Visitor

      BIN_OP_TEMPLATES = {
          :"&&" => lambda { |lhs, rhs| "πg.And(πF, #{lhs}, #{rhs})" },
          :"||" => lambda { |lhs, rhs| "πg.Or(πF, #{lhs}, #{rhs})" },
          :^ => lambda { |lhs, rhs| "πg.Xor(πF, #{lhs}, #{rhs})" },
          :+ => lambda { |lhs, rhs| "πg.Add(πF, #{lhs}, #{rhs})" },
          :/ => lambda { |lhs, rhs| "πg.Div(πF, #{lhs}, #{rhs})" },
          # :// => lambda { |lhs, rhs | "πg.FloorDiv(πF, #{lhs}, #{rhs})" },
          :<< => lambda { |lhs, rhs| "πg.LShift(πF, #{lhs}, #{rhs})" },
          :% => lambda { |lhs, rhs| "πg.Mod(πF, #{lhs}, #{rhs})" },
          :* => lambda { |lhs, rhs| "πg.Mul(πF, #{lhs}, #{rhs})" },
          :** => lambda { |lhs, rhs| "πg.Pow(πF, #{lhs}, #{rhs})" },
          :>> => lambda { |lhs, rhs| "πg.RShift(πF, #{lhs}, #{rhs})" },
          :- => lambda { |lhs, rhs| "πg.Sub(πF, #{lhs}, #{rhs})" },
          :== => lambda { |lhs, rhs| "πg.Eq(πF, #{lhs}, #{rhs})" },
          :> => lambda { |lhs, rhs| "πg.GT(πF, #{lhs}, #{rhs})" },
          :>= => lambda { |lhs, rhs| "πg.GE(πF, #{lhs}, #{rhs})" },
          :< => lambda { |lhs, rhs| "πg.LT(πF, #{lhs}, #{rhs})" },
          :<= => lambda { |lhs, rhs| "πg.LE(πF, #{lhs}, #{rhs})" },
          :!= => lambda { |lhs, rhs| "πg.NE(πF, #{lhs}, #{rhs})" }
      }

      UNARY_OP_TEMPLATES = {
          :~ => lambda { |operand| "πg.Invert(πF, #{operand})" },
          :-@ => lambda { |operand| "πg.Neg(πF, #{operand})" }
      }

      def initialize(stmt_visitor)
        super(block: stmt_visitor.block, parent: stmt_visitor, writer:  stmt_visitor.writer, nodetype_map:
            {
                array: 'array',
                assign: 'assign',
                assoclist_from_args: 'assoclist_from_args',
                assoc_new: 'assoc_new',
                binary: 'binary',
                hash: 'hash',
                '@ident': 'ident',
                unary: 'unary',
                var_field: 'var_field',
                var_ref: 'var_ref',
                string_literal: 'string_literal',
                string_content: 'string_content',
                '@int': 'num',
                '@float': 'num',
                '@kw': 'kw',
                '@tstring_content': 'tstring_content',
                method_add_arg: 'method_add_arg',
                fcall: 'fcall',
                arg_paren: 'arg_paren',
                args_add_block: 'args_add_block'
            }
        )
      end

      def visit_binary(node)
        trace_activity(__method__.to_s)

        # e.g. [:binary, [:@int, "1", [1, 0]], :+, [:@int, "1", [1, 4]]]
        raise CompileError.new(node, msg: 'Node size must be 4.') unless node.length == 4
        lhs = visit(node[1])&.expr
        operator = node[2]
        rhs = visit(node[3])&.expr
        raise CompileError.new(node, msg: 'There is lack of operands.') unless lhs && rhs

        result = @block.alloc_temp

        if BIN_OP_TEMPLATES.has_key?(operator) then
          call = BIN_OP_TEMPLATES[operator].call(lhs, rhs)
          @writer.write_checked_call2(result, call)
        elsif operator === :=== then
          @writer.write("#{result.name} = πg.GetBool(#{lhs} == #{rhs}).ToObject()")
        else
          raise CompileError.new(node, msg: "The operator '#{operator}' is not supported. " +
              'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
        end

        return result
      end

      def visit_unary(node)
        trace_activity(__method__.to_s)

        # e.g. [:unary, :-@, [:@int, "123", [1, 1]]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        operator = node[1]
        operand = visit(node[2])&.expr
        raise CompileError.new(node, msg: 'There is lack of operands.') unless operand

        result = @block.alloc_temp

        if UNARY_OP_TEMPLATES.has_key?(operator) then
          call = UNARY_OP_TEMPLATES[operator].call(operand)
          @writer.write_checked_call2(result, call)
        elsif operator === :not
          is_true = @block.alloc_temp('bool')
          @writer.write_checked_call2(is_true, "πg.IsTrue(πF, #{operand})")
          @writer.write("#{result.name} = πg.GetBool(!#{is_true.expr}).ToObject()")
        else
          raise CompileError.new(node, msg: "The operator '#{operator}' is not supported. " +
              'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
        end

        return result
      end

      def visit_var_ref(node)
        trace_activity(__method__.to_s)

        # e.g. [:var_ref, [:@kw, "true", [1, 0]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        var_node = node[1]
        case var_node[0]
        when '@kw'.to_sym, '@ident'.to_sym then
          var = visit_typed_node(var_node, var_node[0])
        else
          raise CompileError.new(node, msg: "'#{var_node[0]}' is unexpected branch type in this context. " +
              'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
        end
        raise CompileError.new(node, msg: 'Keyword mult not be nil.') if var.nil?

        return @block.resolve_name(@writer, var)
      end

      def visit_kw(node)
        trace_activity(__method__.to_s)

        # e.g. [:@kw, "true", [1, 0]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        return node[1]
      end

      def visit_num(node)
        trace_activity(__method__.to_s)

        # e.g. [:@int, "1", [1, 0]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        type = node[0]
        number = node[1]
        case type
        when :@int then
          expr_str = "NewInt(%d)" % number
        when :@float then
          expr_str = "NewFloat(%f)" % number
        else
          raise CompileError.new(node, "The number type '#{type}' is not supported ." +
              'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
        end

        return Literal.new('πg.' + expr_str + '.ToObject()')
      end

      def visit_string_literal(node)
        trace_activity(__method__.to_s)

        # e.g. [:string_literal, [:string_content, [:@tstring_content, "this is a string expression\\n", [1, 1]]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        # TODO : Check if the string is unicode and generate 'πg.NewUnicode({}).ToObject()'

        return visit_typed_node(node[1], :string_content)
      end

      def visit_string_content(node)
        trace_activity(__method__.to_s)

        # e.g. [:string_content, [:@tstring_content, "this is a string expression\\n", [1, 1]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        return visit_typed_node(node[1], '@tstring_content'.to_sym)
      end

      def visit_tstring_content(node)
        trace_activity(__method__.to_s)

        # e.g. [:@tstring_content, "this is a string expression\\n", [1, 1]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        str = node[1]
        expr_str = "%s.ToObject()" % @block.root.intern(str)
        return Literal.new(expr_str)
      end

      def visit_array(node)
        trace_activity(__method__.to_s)

        # e.g. [:array, [[:@int, "1", [1, 1]], [:@int, "2", [1, 4]], [:@int, "3", [1, 7]]]
        raise CompileError.new(node, msg: 'Node size must be more than 1.') unless node.length > 1

        result = nil
        with(elems: visit_sequential_elements(node[1])) do |temps|
          result = @block.alloc_temp
          @writer.write("#{result.expr} = πg.NewList(#{temps[:elems].expr}...).ToObject()")
        end
        return result
      end

      private def visit_sequential_elements(nodes)
        result = @block.alloc_temp('[]*πg.Object')
        @writer.write("#{result.expr} = make([]*πg.Object, #{nodes.length})")
        nodes.each_with_index do |node, i|
          with(elem: visit(node)) do |temps|
           @writer.write("#{result.expr}[#{i}] = #{temps[:elem].expr}")
          end
        end
        return result
      end

      def visit_hash(node)
        trace_activity(__method__.to_s)

        # e.g. [:hash, [:assoclist_from_args, [[:assoc_new, [:@int, "1", [1, 2]], [:@int, "2", [1, 7]]]]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        result = nil
        with(hash: @block.alloc_temp('*πg.Dict')) do |temps|
          @writer.write("#{temps[:hash].name} = πg.NewDict()")
          visit_typed_node(node[1], :assoclist_from_args, hash: temps[:hash])
          result = @block.alloc_temp
          @writer.write("#{result.name} = #{temps[:hash].expr}.ToObject()")
        end

        return result
      end

      def visit_assoclist_from_args(node, **args)
        trace_activity(__method__.to_s)

        # e.g. [:assoclist_from_args, [[:assoc_new, [:@int, "1", [1, 2]], [:@int, "2", [1, 7]]]]]
        raise CompileError.new(node, msg: 'Node must have Array.') unless node[1].is_a?(Array)

        node[1].each do |assoc_new_node|
          visit_typed_node(assoc_new_node, :assoc_new, **args)
        end
      end

      def visit_assoc_new(node, **args)
        trace_activity(__method__.to_s)

        # e.g. [:assoc_new, [:@int, "1", [1, 2]], [:@int, "2", [1, 7]]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        with(key: visit(node[1]), value: visit(node[2])) do |temps|
          @writer.write_checked_call1("#{args[:hash].expr}.SetItem(πF, #{temps[:key].expr}, #{temps[:value].expr})")
        end
      end

      def visit_assign(node)
        trace_activity(__method__.to_s)

        # e.g. [:assign, [:var_field, [:@ident, "foo", [1, 0]]], [:@int, "1", [1, 6]]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        with(value: visit(node[2])) do |temps|
          target = visit_typed_node(node[1], :var_field)
          @block.bind_var(@writer, target, temps[:value].expr)
        end
      end

      def visit_ident(node)
        trace_activity(__method__.to_s)

        # e.g. [:@ident, "foo", [1, 0]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        return node[1]
      end

      def visit_var_field(node)
        trace_activity(__method__.to_s)

        # e.g. [:var_field, [:@ident, "foo", [1, 0]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        return visit_typed_node(node[1], '@ident'.to_sym)
      end

      def visit_method_add_arg(node)
        trace_activity(__method__.to_s)

        # e.g. [:method_add_arg,
        #       [:fcall, [:@ident, "puts", [1, 0]]],
        #       [:arg_paren, [:args_add_block, [[:@int, "1", [1, 5]]], false]]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        arg_info = visit_typed_node(node[2], :arg_paren)
        argc = arg_info[:argc]
        argv = arg_info[:argv]
        result = nil

        with(args: argv, func: visit_typed_node(node[1], :fcall)) do |temps|
          result = @block.alloc_temp
          @writer.write_checked_call2(result, "#{temps[:func].expr}.Call(πF, #{temps[:args].expr}, #{NIL_EXPR.expr})")
        end

        if argc > 0
          @writer.write("πF.FreeArgs(#{argv.expr})")
        end

        return result
      end

      def visit_fcall(node)
        trace_activity(__method__.to_s)

        # e.g. [:fcall, [:@ident, "puts", [1, 0]]],
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 2

        return @block.resolve_name(@writer, visit_typed_node(node[1], '@ident'.to_sym))
      end

      def visit_arg_paren(node)
        trace_activity(__method__.to_s)

        # e.g. [:arg_paren, [:args_add_block, [[:@int, "1", [1, 5]]], false]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        return visit_typed_node(node[1], :args_add_block)
      end

      def visit_args_add_block(node)
        trace_activity(__method__.to_s)

        # e.g. [:args_add_block, [[:@int, "1", [1, 5]]], false]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        # Build positional arguments.
        argc = node[1].length
        argv = NIL_EXPR

        unless node[1].empty?
          argv = self.block.alloc_temp('[]*πg.Object')
          @writer.write("#{argv.expr} = πF.MakeArgs(#{argc})")
          node[1].each_with_index do |node, i|
            with(arg: visit(node)) do |temps|
              @writer.write("#{argv.expr}[#{i}] = #{temps[:arg].expr}")
            end
          end
        end

        return { argc: argc, argv: argv }
      end
    end

  end
end

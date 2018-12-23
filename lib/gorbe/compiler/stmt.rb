require 'gorbe/compiler/expr'

module Gorbe
  module Compiler

    # A class which generates Go code based on Ruby AST (Statement).
    class StatementVisitor < Visitor

      def initialize(block)
        super(block: block, writer: Writer.new, nodetype_map:
            {
                array: 'expr',
                assign: 'expr',
                hash: 'expr',
                program: 'program',
                void_stmt: 'void_stmt',
                binary: 'expr',
                unary: 'expr',
                '@ident': 'expr',
                '@int': 'expr',
                '@float': 'expr',
                aref: 'expr',
                var_field: 'expr',
                var_ref: 'expr',
                string_literal: 'expr',
                case: 'case',
                when: 'when',
                if: 'if_or_unless',
                if_mod: 'if_or_unless',
                elsif: 'if_or_unless',
                unless: 'if_or_unless',
                unless_mod: 'if_or_unless',
                else: 'else',
                method_add_arg: 'expr',
                fcall: 'expr',
                while: 'while',
                arg_paren: 'expr',
                args_add_block: 'expr',
                def: 'def',
                bodystmt: 'bodystmt',
                return: 'return',
                return0: 'return',
                class: 'class',
                const_ref: 'expr',
                '@const': 'expr'
            }
        )
        @expr_visitor = Compiler::ExprVisitor.new(self)
      end

      # e.g. [:program, [[:void_stmt]]]
      def visit_program(node)
        raise CompileError.new(node, msg: 'Node size must be more than 1.') unless node.length > 1

        children = node.slice(1..-1)
        children.each do |child|
          visit(child)
        end
      end

      private def is_lineno_node?(node)
        return node.is_a?(Array) && node.length == 2 && node[0].is_a?(Integer) && node[1].is_a?(Integer)
      end

      def visit_expr(node)
        # Check lineno
        expr_node = node
        until is_lineno_node?(expr_node[-1])
          expr_node = expr_node[1]
          break if expr_node.nil? # Lineno not found
        end

        unless expr_node.nil?
          lineno = expr_node[-1][0]
          write_rb_context(lineno)
        end

        return @expr_visitor.visit(node)
      end

      def visit_void_stmt(node)
        # Do nothing
      end

      # e.g. [:case, $expr, [:when, ...]]
      def visit_case(node)
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        bodies = [] # Branch bodies
        with(visit(node[1])) do |case_expr|

          # Generate condition for "when" statement
          condition_generator = lambda do |val_expr_nodes|
            condition = @block.alloc_temp
            val_expr_nodes.each_with_index do |val_expr_node, i|
              with(visit(val_expr_node)) do |val|
                if i == 0
                  @writer.write_checked_call2(condition, "πg.Eq(πF, #{case_expr.expr}, #{val.expr})")
                else
                  with(@block.alloc_temp) do |single_condition|
                    @writer.write_checked_call2(single_condition, "πg.Eq(πF, #{case_expr.expr}, #{val.expr})")
                    @writer.write_checked_call2(condition, "πg.Or(πF, #{condition.expr}, #{single_condition.expr})")
                  end
                end
              end
            end
            return condition
          end

          visit_typed_node(node[2], :when, cond_gen: condition_generator, bodies: bodies)
        end
      end

      # e.g. [:when, $expr, [$expr, $expr...], [:else, ...]]
      def visit_when(node, cond_gen:, bodies:)
        raise CompileError.new(node, msg: 'Node size must be 4.') unless node.length == 4

        visit_branch(node, bodies, node[0], cond_gen, node[2], node[3])
      end

      private def visit_branch(node, bodies, branch_type, cond_gen, body_node, next_branch_node)
        # Check if '!' is needed for the condition depending on the branch type
        case branch_type
        when :if, :elsif, :if_mod, :when then
          is_not = false
        when :unless, :unless_mod then
          is_not = true
        else
          raise CompileError.new(node, msg: 'Unsupported branch node.')
        end

        label = @block.gen_label
        with(cond_gen.call(node[1]), @block.alloc_temp('bool')) do |condition, is_true|
          template = <<~EOS
            if #{is_true.expr}, πE = πg.IsTrue(πF, #{condition.expr}); πE != nil {
            \tcontinue
            }
            if #{is_not ? '!' : ''}#{is_true.expr} {
            \tgoto Label#{label}
            }
          EOS
          @writer.write(template)
        end
        bodies.push([label, body_node])

        if next_branch_node.nil?  # If there is no 'else' statement
          end_label = @block.gen_label
          @writer.write("goto Label%d" % end_label)

          # Write labels and bodies
          bodies.each do |body|
            @writer.write_label(body[0])
            visit(body[1])
            @writer.write("goto Label%d" % end_label)
          end
          @writer.write_label(end_label)
        else  # If there is 'elsif', 'else' or 'when' statement
          case next_branch_node[0]
          when :when then
            visit_typed_node(next_branch_node, :when, cond_gen: cond_gen, bodies: bodies)
          when :elsif, :else then
            visit_typed_node(next_branch_node, next_branch_node[0], bodies: bodies)
          else
            raise CompileError.new(node, msg: "'#{next_branch_node[0]}' is unexpected branch type in this context. " +
                               'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
          end
        end
      end

      # e.g. [:if, $cond_expr, [$expr, $expr...], [:elsif, $cond_expr, [$expr, $expr...], [:else, [$expr, $expr]]]
      #      [:if_mod, $cond_expr, $expr]
      def visit_if_or_unless(node, bodies: nil)
        raise CompileError.new(node, msg: 'Node size must be 4.') unless node.length == 3 || node.length == 4

        visit_branch(node, bodies.nil? ? [] : bodies, node[0], lambda { |node| return visit(node) }, node[2], node[3])
      end

      # e.g. [:else, [$expr, $expr...]]
      def visit_else(node, bodies:)
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        default_label = @block.gen_label
        bodies.push([default_label, node[1]])
        @writer.write("goto Label%d" % default_label)
        end_label = @block.gen_label

        # Write labels and bodies
        bodies.each do |body|
          @writer.write_label(body[0])
          visit(body[1])
          @writer.write("goto Label%d" % end_label)
        end
        @writer.write_label(end_label)
      end

      def visit_while(node)
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        test_func = lambda do |test_var|
          with(visit(node[1])) do |condition|
            @writer.write_checked_call2(test_var, "πg.IsTrue(πF, #{condition.expr})")
          end
        end

        visit_loop(test_func, node)
      end

      private def visit_loop(test_func, node)
        start_label = @block.gen_label(true)
        else_label = @block.gen_label(true)
        end_label = @block.gen_label
        with(block.alloc_temp('bool')) do |break_var|
          @block.push_loop(break_var)
          @writer.write("πF.PushCheckpoint(#{else_label})")
          @writer.write("#{break_var.name} = false")
          @writer.write_label(start_label)
          tmpl = <<~EOS
            if πE != nil || πR != nil {
            \tcontinue
            }
            if #{break_var.expr} {
            \tπF.PopCheckpoint()
            \tgoto Label#{end_label}
            }
          EOS
          @writer.write(tmpl)
          with(@block.alloc_temp('bool')) do |test_var|
            test_func.call(test_var)
            tmpl = <<~EOS
              if πE != nil || !#{test_var.name} {
              \tcontinue
              }
              πF.PushCheckpoint(#{start_label})
            EOS
            @writer.write(tmpl)
          end
          visit(node[2])
          @writer.write('continue')

          # End the loop so that break applies to an outer loop if present.
          @block.pop_loop
          @writer.write_label(else_label)
          tmpl = <<~EOS
            if πE != nil || πR != nil {
            \tcontinue
            }
          EOS
          @writer.write(tmpl)

          # if node.orelse
          #   visit_each(node.orelse)
          # end
          @writer.write_label(end_label)
        end
      end

      # Check if the method needs 'self' as the first arg
      private def is_instance_method?
        # TODO : Need to consider class method.
        return @block.is_a?(ClassBlock)
      end

      def visit_def(node)
        func_name = visit_typed_node(node[1], '@ident'.to_sym)
        is_constructor = is_instance_method? && func_name === 'initialize'
        func = visit_function_inline(node, is_instance_method?)
        @block.bind_var(@writer, is_constructor ? '__init__' : func_name, func.expr)
      end

      private def visit_function_inline(node, is_constructor)
        func_visitor = FunctionBlockVisitor.new(node: node, is_constructor: is_constructor)
        func_name = func_visitor.visit_typed_node(node[1], '@ident'.to_sym)
        func_visitor.visit(node[3])
        func_block = FunctionBlock.new(@block, func_name, func_visitor.vars)
        visitor = StatementVisitor.new(func_block)

        visitor.writer.indent_block(1) do
          visitor.visit(node[3])
        end

        result = @block.alloc_temp
        with(@block.alloc_temp('[]πg.Param')) do |func_args|
          args = func_visitor.vars
          argc = args.length
          @writer.write("#{func_args.expr} = make([]πg.Param, #{argc})")

          # TODO : Handle default args appropriately
          args.each_with_index do |(key, val), i|
            with(NIL_EXPR) do |default|
              tmpl = "#{func_args.expr}[#{i}] = πg.Param{Name: #{Util::generate_go_string(key)}, Def: #{default.expr}}"
              @writer.write(tmpl)
            end
          end

          # TODO : Handle vargs and kwargs appropriately

          go_func_name = Util::generate_go_string(func_name)
          go_filename = Util::generate_go_string('gorbe') # FIXME
          tmpl =
            "#{result.name} = πg.NewFunction(πg.NewCode(#{go_func_name}, #{go_filename}, #{func_args.expr}, " +
            "0, func(πF *πg.Frame, πArgs []*πg.Object) " +
            "(*πg.Object, *πg.BaseException) {"
          @writer.write(tmpl)

          @writer.indent_block(1) do
            func_block.vars.each do |name, var|
              unless var.type == Var::TYPE_GLOBAL
                go_var_name = Util::get_go_identifier(var.name)
                @writer.write("var #{go_var_name} *πg.Object = #{var.init_expr}; _ = #{go_var_name}")
              end
            end

            @writer.write_temp_decls(func_block)
            @writer.write('var πR *πg.Object; _ = πR')
            @writer.write('var πE *πg.BaseException; _ = πE')
            @writer.write_block(func_block, visitor.writer.value)

            tmpl = <<~EOS
              if πE != nil {
              \tπR = nil
              } else if πR == nil {
              \tπR = πg.None
              }
              return πR, πE
            EOS
            @writer.write(tmpl)
          end
          @writer.write('}), πF.Globals()).ToObject()')
        end
        return result
      end

      def visit_bodystmt(node)
        raise CompileError.new(node, msg: 'Node size must be 5.') unless node.length == 5

        return visit(node[1])
      end

      # e.g. [:return, [:args_add_block, [[$expr, $expr...], false]]
      def visit_return(node)
        raise CompileError.new(node, msg: '"return" should be called in a method.') unless @block.is_a?(FunctionBlock)
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        if node[0] === :return
          with(visit_typed_node(node[1], :args_add_block)[:argv]) do |value|
            @writer.write("πR = #{value.expr}[0]")  # TODO : Support returning multiple values
          end
        else
          @writer.write('πR = πg.None')
        end
        @writer.write('continue')
      end

      # e.g. [:class, [:const_ref, [:@const, "Foo", [1, 6]]], nil, [:bodystmt, [$stmt, $stmt...]]]
      def visit_class(node)
        raise CompileError.new(node, msg: 'Node size must be 5.') unless node.length == 4
        raise CompileError.new(node, msg: 'Body statement is necessary in class definition.') unless is_node?(node[3], :bodystmt)

        block_visitor = BlockVisitor.new
        block_visitor.visit_typed_node(node[3], :bodystmt)

        global_vars = block_visitor.vars.select { |_, var| var.type === Var::TYPE_GLOBAL }

        # Visit all the statements inside of the class declaration.
        class_name = visit_typed_node(node[1], :const_ref)
        body_visitor = StatementVisitor.new(ClassBlock.new(@block, class_name, global_vars))

        # Indent so that the method body is aligned with the goto labels.
        body_visitor.writer.indent_block do
          body_visitor.visit(node[3])
        end

        with(@block.alloc_temp('*πg.Dict'),
             @block.alloc_temp,
             @block.alloc_temp('[]*πg.Object'),
             @block.alloc_temp) do |cls, mod_name, bases, meta|
          if node[2].nil?
            @writer.write("#{bases.expr} = make([]*πg.Object, 1)")
          else
            # TODO : Consider other super classes
          end

          base_node = [:var_ref, [:@kw, 'object', [-1, 0]]]  # FIXME : Consider other super classes
          with(visit_expr(base_node)) do |base_expr|
            @writer.write("#{bases.expr}[0] = #{base_expr.expr}")
          end

          @writer.write("#{cls.name} = πg.NewDict()")
          @writer.write_checked_call2(
              mod_name, "πF.Globals().GetItem(πF, #{@block.root.intern('__name__')}.ToObject())")
          @writer.write_checked_call1(
              "#{cls.expr}.SetItem(πF, #{@block.root.intern('__module__')}.ToObject(), #{mod_name.expr})")

          go_class_name = Util::generate_go_string(class_name)
          go_filename = Util::generate_go_string('gorbe') # FIXME
          tmpl = <<~EOS
              _, πE = πg.NewCode(#{go_class_name}, #{go_filename}, nil, 0, func(πF *πg.Frame, _ []*πg.Object) (*πg.Object, *πg.BaseException) {
              \tπClass := #{cls.expr}
              \t_ = πClass
          EOS
          @writer.write(tmpl)

          @writer.indent_block do
            @writer.write_temp_decls(body_visitor.block)
            @writer.write_block(body_visitor.block,
                                body_visitor.writer.value)
            @writer.write('return nil, nil')
          end

          tmpl = <<~EOS
              }).Eval(πF, πF.Globals(), nil, nil)
              if πE != nil {
              \tcontinue
              }
              if #{meta.name}, πE = #{cls.expr}.GetItem(πF, #{block.root.intern('__metaclass__')}.ToObject()); πE != nil {
              \tcontinue
              }
              if #{meta.name} == nil {
              \t#{meta.name} = πg.TypeType.ToObject()
              }
          EOS
          @writer.write(tmpl)

          with(@block.alloc_temp) do |type|
            type_expr = "#{meta.expr}.Call(πF, []*πg.Object{πg.NewStr(#{Util::generate_go_string(class_name)}).ToObject(), " +
                "πg.NewTuple(#{bases.expr}...).ToObject(), #{cls.expr}.ToObject()}, nil)"
            @writer.write_checked_call2(type, type_expr)
            @block.bind_var(@writer, class_name, type.expr)
          end
        end
      end

      # A method for writing Ruby context
      private def write_rb_context(lineno)
        line = @block.root.buffer.get_source_line(lineno).strip
        @writer.write("// line #{lineno}: #{line}")
        @writer.write("πF.SetLineno(#{lineno})")
      end
    end

  end
end

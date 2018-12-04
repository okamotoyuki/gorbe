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
                bodystmt: 'bodystmt'
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

      def visit_expr(node)
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

      # e.g.
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

      def visit_def(node)
        func = visit_function_inline(node)
        @block.bind_var(@writer, visit_typed_node(node[1], '@ident'.to_sym), func.expr)
      end

      private def visit_function_inline(node)
        func_visitor = FunctionBlockVisitor.new(node: node)
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
          end
          @writer.write('}), πF.Globals()).ToObject()')
        end
        return result
      end

      def visit_bodystmt(node)
        raise CompileError.new(node, msg: 'Node size must be 5.') unless node.length == 5

        return visit(node[1])
      end

    end
  end
end

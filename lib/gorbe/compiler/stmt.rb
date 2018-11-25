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
                arg_paren: 'expr',
                args_add_block: 'expr'
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
        with(case_expr: visit(node[1])) do |temps|

          # Generate condition for "when" statement
          condition_generator = lambda do |val_expr_nodes|
            condition = @block.alloc_temp
            val_expr_nodes.each_with_index do |val_expr_node, i|
              with(val: visit(val_expr_node)) do |temps2|
                if i == 0
                  @writer.write_checked_call2(condition, "πg.Eq(πF, #{temps[:case_expr].expr}, #{temps2[:val].expr})")
                else
                  with(single_condition: @block.alloc_temp) do |temps3|
                    @writer.write_checked_call2(temps3[:single_condition], "πg.Eq(πF, #{temps[:case_expr].expr}, #{temps2[:val].expr})")
                    @writer.write_checked_call2(condition, "πg.Or(πF, #{condition.expr}, #{temps3[:single_condition].expr})")
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
        with(condition: cond_gen.call(node[1]), is_true: @block.alloc_temp('bool')) do |temps|
          template = <<~EOS
            if #{temps[:is_true].expr}, πE = πg.IsTrue(πF, #{temps[:condition].expr}); πE != nil {
            \tcontinue
            }
            if #{is_not ? '!' : ''}#{temps[:is_true].expr} {
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

    end
  end
end

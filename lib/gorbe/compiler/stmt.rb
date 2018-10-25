require 'gorbe/compiler/expr'

module Gorbe
  module Compiler

    # A class which generates Go code based on Ruby AST (Statement).
    class StatementVisitor < Visitor

      def initialize(block)
        super(block: block, writer: Writer.new, nodetype_map:
            {
                array: 'expr',
                assign: 'assign',
                hash: 'expr',
                program: 'program',
                void_stmt: 'void_stmt',
                binary: 'expr',
                unary: 'expr',
                '@ident': 'ident',
                '@int': 'expr',
                '@float': 'expr',
                var_field: 'var_field',
                var_ref: 'expr',
                string_literal: 'expr',
                case: 'case',
                if: 'if_or_unless',
                if_mod: 'if_or_unless',
                elsif: 'if_or_unless',
                unless: 'if_or_unless',
                unless_mod: 'if_or_unless',
                else: 'else'
            }
        )
        @expr_visitor = Compiler::ExprVisitor.new(self)
      end

      def visit_program(node)
        log_activity(__method__.to_s)

        # e.g. [:program, [[:void_stmt]]]
        raise CompileError.new(node, msg: 'Node size must be more than 1.') unless node.length > 1

        children = node.slice(1..-1)
        children.each do |child|
          visit(child)
        end
      end

      def visit_assign(node)
        log_activity(__method__.to_s)

        # e.g. [:assign, [:var_field, [:@ident, "foo", [1, 0]]], [:@int, "1", [1, 6]]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        with(value: visit(node[2])) do |temps|
          target = visit(node[1])
          @block.bind_var(@writer, target, temps[:value].expr)
        end
      end

      def visit_expr(node)
        log_activity(__method__.to_s)
        return @expr_visitor.visit(node)
      end

      def visit_ident(node)
        log_activity(__method__.to_s)

        # e.g. [:@ident, "foo", [1, 0]]
        raise CompileError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        return node[1]
      end

      def visit_var_field(node)
        log_activity(__method__.to_s)

        # e.g. [:var_field, [:@ident, "foo", [1, 0]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        return visit(node[1])
      end

      def visit_void_stmt(node)
        # Do nothing
      end

      # def visit_case(node)
      #   log_activity(__method__.to_s)
      #
      #   # e.g. [:case, [:var_ref, [:@ident, "foo", [3, 5]]],
      #   #       [:when, [[:@int, "1", [4, 5]]], [[:@int, "2", [5, 1]]],
      #   #       [:else, [[:@int, "3", [7, 1]]]]]]
      #   raise CompileError.new(node, msg: 'Node size must be more than 2.') unless node.length > 2
      #
      #   with(target: visit(node[1])) do |temps|
      #     node[2..node.length-1].each do |node|
      #
      #     end
      #   end
      # end

      private def visit_branch(node, bodies, branch_type, branch_condition, branch_body, next_branch_body=nil)
        # Check if '!' is needed for the condition depending on the branch type
        case branch_type
        when :if, :elsif, :if_mod then
          is_not = false
        when :unless, :unless_mod then
          is_not = true
        else
          raise CompileError.new(node, msg: 'Unsupported branch node.')
        end

        label = @block.gen_label
        with(is_true: @block.alloc_temp('bool')) do |bool_temps|
          template = <<~EOS
            if #{bool_temps[:is_true].expr}, πE = πg.IsTrue(πF, #{branch_condition.expr}); πE != nil {
            \tcontinue
            }
            if #{is_not ? '!' : ''}#{bool_temps[:is_true].expr} {
            \tgoto Label#{label}
            }
          EOS
          @writer.write(template)
        end
        bodies.push([label, branch_body])

        if next_branch_body.nil?  # If there is no 'else' statement
          end_label = @block.gen_label

          # Write labels and bodies
          bodies.each do |body|
            @writer.write_label(body[0])
            visit(body[1])
            @writer.write("goto Label%d" % end_label)
          end
          @writer.write_label(end_label)
        else  # If there is 'elsif' or 'else' statement
          visit(next_branch_body, bodies: bodies)
        end
      end

      def visit_if_or_unless(node, **args)
        log_activity(__method__.to_s)

        # e.g. [:if, [:var_ref, [:@kw, "true", [1, 3]]], [[:@int, "1", [2, 2]]],
        #       [:elsif, [:var_ref, [:@kw, "false", [3, 6]]], [[:@int, "2", [4, 2]]],
        #       [:else, [[:@int, "3", [6, 2]]]]]]
        #
        #      [:if_mod, [:var_ref, [:@kw, "true", [9, 5]]], [:@int, "1", [9, 0]]]
        raise CompileError.new(node, msg: 'Node size must be 4.') unless node.length == 3 || node.length == 4

        # Branch bodies
        bodies = args[:bodies].nil? ? [] : args[:bodies]

        with(cond: visit(node[1])) do |temps|
          visit_branch(node, bodies, node[0], temps[:cond], node[2], node[3])
        end
      end

      def visit_else(node, **args)
        log_activity(__method__.to_s)

        # e.g. [:else, [[:@int, "3", [6, 2]]]]
        raise CompileError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        # 'if'/'else'/'elsif' bodies
        bodies = args[:bodies]
        default_label = @block.gen_label
        bodies.push([default_label, node[1]])
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

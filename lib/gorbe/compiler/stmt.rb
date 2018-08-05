require 'gorbe/compiler/expr'

module Gorbe
  module Compiler

    class StatementVisitor < Visitor

      def initialize(block)
        super(block=block)
        @nodetype_map = {
          program: 'program',
          binary: 'expr'
        }
      end

      def visit_program(node)
        print_activity(__method__.to_s)
        children = node.slice(1..-1)

        children.each do |child|
          visit(child)
        end
      end

      def visit_expr(node)
        print_activity(__method__.to_s)
        expr_visitor = Compiler::ExprVisitor.new(self)
        expr_visitor.visit(node)
      end
    end

  end
end

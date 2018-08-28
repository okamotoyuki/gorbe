require 'gorbe/compiler/expr'

module Gorbe
  module Compiler

    class StatementVisitor < Visitor

      def initialize(block)
        super(block: block, writer: Writer.new, nodetype_map:
            {
                program: 'program',
                binary: 'expr'
            }
        )
        @expr_visitor = Compiler::ExprVisitor.new(self)
      end

      def visit_program(node)
        log_activity(__method__.to_s)
        children = node.slice(1..-1)

        children.each do |child|
          visit(child)
        end
      end

      def visit_expr(node)
        log_activity(__method__.to_s)
        @expr_visitor.visit(node)
      end

    end
  end
end

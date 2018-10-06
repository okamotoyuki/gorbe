require 'gorbe/compiler/expr'

module Gorbe
  module Compiler

    # A class which generates Go code based on Ruby AST (Statement).
    class StatementVisitor < Visitor

      def initialize(block)
        super(block: block, writer: Writer.new, nodetype_map:
            {
                program: 'program',
                void_stmt: 'void_stmt',
                binary: 'expr',
                unary: 'expr',
                '@int': 'expr',
                var_ref: 'expr'
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
        @expr_visitor.visit(node).free
      end

      def visit_void_stmt(node)
        # Do nothing
      end

    end
  end
end

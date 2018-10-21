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
                string_literal: 'expr'
            }
        )
        @expr_visitor = Compiler::ExprVisitor.new(self)
      end

      def visit_program(node)
        log_activity(__method__.to_s)

        # e.g. [:program, [[:void_stmt]]]
        raise ParseError.new(node, msg: 'Node size must be more than 1.') unless node.length > 1

        children = node.slice(1..-1)
        children.each do |child|
          visit(child)
        end
      end

      def visit_assign(node)
        log_activity(__method__.to_s)

        # e.g. [:assign, [:var_field, [:@ident, "foo", [1, 0]]], [:@int, "1", [1, 6]]]
        raise ParseError.new(node, msg: 'Node size must be 3.') unless node.length == 3

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
        raise ParseError.new(node, msg: 'Node size must be 3.') unless node.length == 3

        return node[1]
      end

      def visit_var_field(node)
        log_activity(__method__.to_s)

        # e.g. [:var_field, [:@ident, "foo", [1, 0]]]
        raise ParseError.new(node, msg: 'Node size must be 2.') unless node.length == 2

        return visit(node[1])
      end

      def visit_void_stmt(node)
        # Do nothing
      end

    end
  end
end

module Gorbe
  module Compiler

    class ExprVisitor < Visitor
      def initialize(stmt_visitor)
        super(parent=stmt_visitor)
        @depth = stmt_visitor.depth
        @nodetype_map = {
          binary: 'binop',
          '@int': 'int'
        }
      end

      def visit_binop(node)
        print_activity(__method__.to_s)

        raise if node.length != 4 # TODO : Raise an appropriate exception

        lhs = node[1]
        operator = node[2]
        rhs = node[3]
      end

      def visit_int(node)
        print_activity(__method__.to_s)
      end
    end

  end
end

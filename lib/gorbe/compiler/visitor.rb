module Gorbe
  module Compiler

    # A visitor class for traversing Ruby AST
    class Visitor
      attr_reader :depth

      def initialize(block=nil, parent=nil)
        @depth = 0
        @nodetype_map = {}
      end

      # Print visitor activity
      def print_activity(method_name)
        Gorbe.debug('  ' * (@depth - 1) + '(' + method_name + ')')
      end

      # Traverse Ruby AST
      def visit(ast)
        @depth += 1

        if ast.empty?
          Gorbe.debug('Node shouldn\'t be empty.')
          @depth -= 1
          raise # TODO : Raise an appropriate exception
        end

        if ast[0].is_a?(Symbol)
          nodetype =
            @nodetype_map.key?(ast[0]) ? @nodetype_map[ast[0]] : 'general'
          send("visit_#{nodetype}", ast)
        elsif ast[0].is_a?(Array)
          ast.each do |node|
            visit(node)
          end
        else
          Gorbe.debug('Not supported AST node!')
          Gorbe.debug(ast)
          raise # TODO : Raise an appropriate exception
        end

        @depth -= 1
      end

      def visit_general(node)
        Gorbe.debug("AST node '#{node[0]}' is currently not supported yet." +
          'Please contact us via xxx.')
        Gorbe.debug(node)
        raise # TODO : Raise an appropriate exception
      end
    end

  end
end

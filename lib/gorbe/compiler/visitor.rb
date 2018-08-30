module Gorbe
  module Compiler

    # A visitor class for traversing Ruby AST
    class Visitor
      attr_reader :block
      attr_reader :parent
      attr_reader :writer
      attr_reader :depth

      def initialize(block: nil, parent: nil, writer: nil, nodetype_map: {})
        @block = block
        @parent = parent
        @writer = writer
        @nodetype_map = nodetype_map
        @depth = 0
      end

      # Print visitor activity
      def log_activity(method_name)

        # Calculate depth
        depth = @depth
        visitor = self
        unless visitor.parent.nil? then
          depth += visitor.parent.depth
          visitor = visitor.parent
        end
        Gorbe.logger.debug('  ' * (depth - 1) + '(' + method_name + ')')
      end

      # Traverse Ruby AST
      def visit(ast)
        @depth += 1

        if ast.empty?
          Gorbe.logger.fatal('Node shouldn\'t be empty.')
          @depth -= 1
          raise # TODO : Raise an appropriate exception
        end

        result = nil # Return value
        if ast[0].is_a?(Symbol)
          nodetype =
            @nodetype_map.key?(ast[0]) ? @nodetype_map[ast[0]] : 'general'
          result = send("visit_#{nodetype}", ast)
        elsif ast[0].is_a?(Array)
          ast.each do |node|
            visit(node)
          end
        else
          Gorbe.logger.fatal('Not supported AST node!')
          Gorbe.logger.debug(ast)
          raise # TODO : Raise an appropriate exception
        end

        @depth -= 1
        return result
      end

      def visit_general(node)
        Gorbe.logger.error("AST node '#{node[0]}' is currently not supported yet." +
                               'Please contact us via https://github.com/OkamotoYuki/gorbe/issues.')
        Gorbe.logger.debug(node)
        raise # TODO : Raise an appropriate exception
      end
    end

  end
end

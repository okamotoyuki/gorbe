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

      # Do something with temporary variables and free them after that
      private def with(**args)
        yield(args) if block_given?

        # Free unused temporary values
        args.each do |key, val|
          val.free
        end
      end

      # Traverse Ruby AST
      def visit(ast, **args)
        @depth += 1
        result = nil # Return value

        if ast.empty?
          Gorbe.logger.debug('  ' * (depth - 1) + '(empty)')
          @depth -= 1
          return result
        end

        if ast[0].is_a?(Symbol) || ast[0].is_a?(String) # TODO : Should we actually consider "String" type?
          nodetype =
            @nodetype_map.key?(ast[0]) ? @nodetype_map[ast[0]] : 'general'
          result =
            args.empty? ? send("visit_#{nodetype}", ast) : send("visit_#{nodetype}", ast, **args)
        elsif ast[0].is_a?(Array)
          ast.each do |node|
            result = visit(node)
          end
        else
          raise ParseError.new(ast, msg: 'Not supported AST node.')
        end

        @depth -= 1
        return result
      end

      def visit_general(node)
        raise ParseError.new(node, "AST node '#{node[0]}' is currently not supported yet. " +
                               'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
      end
    end

  end
end

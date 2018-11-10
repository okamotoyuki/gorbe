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
      def visit(node, lazy_eval_node=nil, **args)
        @depth += 1
        result = nil # Return value

        if node.empty?
          Gorbe.logger.debug('  ' * (depth - 1) + '(empty)')
          @depth -= 1
          return result
        end

        if node[0].is_a?(Symbol) || node[0].is_a?(String) # TODO : Should we actually consider "String" type?
          nodetype =
            @nodetype_map.key?(node[0]) ? @nodetype_map[node[0]] : 'general'
          result =
            lazy_eval_node.nil? && args.empty? ? send("visit_#{nodetype}", node) : send("visit_#{nodetype}", node, lazy_eval_node, **args)
        elsif node[0].is_a?(Array)
          node.each do |single_node|
            result = visit(single_node)
          end
        else
          raise CompileError.new(ast, msg: 'Not supported AST node.')
        end

        @depth -= 1
        return result
      end

      def visit_general(node, lazy_eval_node=nil, **args)
        raise CompileError.new(node, msg: "AST node '#{node[0]}' is currently not supported yet. " +
                               'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
      end
    end

  end
end

require 'gorbe/compiler/error'

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
      private def trace(method_name)
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
      private def _visit(node, nodetype, **args)
        method_type = @nodetype_map.key?(node[0]) ? @nodetype_map[node[0]] : 'general'
        trace(method_type)
        return args.empty? ? send("visit_#{method_type}", node) : send("visit_#{method_type}", node, **args)
      end

      # Visit untyped node
      def visit(node)
        @depth += 1
        result = nil # Return value

        if node.empty?
          Gorbe.logger.debug('  ' * (depth - 1) + '(empty)')
          @depth -= 1
          return result
        end

        if node[0].is_a?(Symbol) || node[0].is_a?(String) # TODO : Should we actually consider "String" type?
          result = _visit(node, node[0])
        elsif node[0].is_a?(Array)
          node.each do |single_node|
            result = visit(single_node)
          end
        else
          raise CompileError.new(node, msg: 'Not supported AST node.')
        end

        @depth -= 1
        return result
      end

      # Visit typed node
      def visit_typed_node(node, nodetype, **args)
        @depth += 1
        result = nil # Return value

        unless node[0] === nodetype
          raise CompileError.new(node, msg: "AST node '#{node[0]}' is unexpected in this context. " +
                               'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
        end

        result = _visit(node, nodetype, **args)
        @depth -= 1
        return result
      end

      # Visit unsupported node
      def visit_general(node, **args)
        raise CompileError.new(node, msg: "AST node '#{node[0]}' is currently not supported yet. " +
                               'Please contact us via https://github.com/okamotoyuki/gorbe/issues.')
      end
    end

  end
end

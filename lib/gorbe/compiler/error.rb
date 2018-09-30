module Gorbe
  module Compiler


    class CompileError < StandardError
      def initialize(node, msg: nil)
        msg = "Node: #{node.to_s} - #{msg}"
        super(msg)
      end
    end

    class ParseError < CompileError
      def initialize(node, msg: nil)
        super
      end
    end

  end
end
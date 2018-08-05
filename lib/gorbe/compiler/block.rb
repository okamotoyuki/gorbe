module Gorbe
  module Compiler

    class Loop

      def initialize
      end

    end

    class Block
      # Represents a Ruby block

      def initialize(parent=nil, name=nil)
        # @root
        @parent = parent
        @name = name
        # @free_temps
        # @used_temps
        # @temp_index
        # @label_count
        # @check_points
        # @loop_stack
        # @is_generator
      end
    end

    class TopLevel < Block

      def initialize
        super(nil, '<toplevel>')
      end

    end

  end
end

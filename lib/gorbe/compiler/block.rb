require 'set'

module Gorbe
  module Compiler

    class Loop

      def initialize
      end

    end

    class Block
      attr_reader :free_temps
      attr_reader :used_temps

      def initialize(parent=nil, name=nil)
        # @root
        @parent = parent
        @name = name
        @free_temps = Set.new
        @used_temps = Set.new
        @temp_index = 0
        # @label_count
        # @check_points
        # @loop_stack
        # @is_generator
      end

      def alloc_temp_var(type: '*πg.Object')
        @free_temps.sort { |v1, v2| v1.name <=> v2.name } .each do |v|
          if v.type == type
            @free_temps.delete(v)
            @used_temps.add(v)
            return v
          end
        end
        @temp_index += 1
        name = "πTemp%03d" % @temp_index
        v = TempVar.new(block: self, name: name, type: type)
        @used_temps.add(v)
        return v
      end

      def free_temp_var(v)
        @used_temps.delete(v)
        @free_temps.add(v)
      end
    end

    class TopLevel < Block

      def initialize
        super(nil, '<toplevel>')
      end

    end

  end
end

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
        v = TempVar.new(name: name, type: type)
        @used_temps.add(v)
        return v
      end
    # for v in sorted(self.free_temps, key=lambda k: k.name):
    #   if v.type_ == type_:
    #     self.free_temps.remove(v)
    #     self.used_temps.add(v)
    #     return v
    # self.temp_index += 1
    # name = 'πTemp{:03d}'.format(self.temp_index)
    # v = expr.GeneratedTempVar(self, name, type_)
    # self.used_temps.add(v)
    # return v

    end

    class TopLevel < Block

      def initialize
        super(nil, '<toplevel>')
      end

    end

  end
end

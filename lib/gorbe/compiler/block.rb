require 'set'

module Gorbe
  module Compiler

    NON_WORD_REGEX = Regexp.new('[^A-Za-z0-9_]')

    class Loop

      def initialize
      end

    end

    class Block
      attr_reader :free_temps
      attr_reader :used_temps

      def initialize(parent=nil, name=nil)
        @root = parent ? parent.root : self
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

      def alloc_temp_var(type='*πg.Object')
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

      private def resolve_global(writer, name)
        result = alloc_temp_var()
        writer.write_checked_call2(
            result, "πg.ResolveGlobal(πF, %s)" % @root.intern(name))
        return result
      end
    end

    class TopLevel < Block

      def initialize
        super(nil, '<toplevel>')
        @strings = Set.new()
      end

      def intern(s)
        if s.length > 64 or NON_WORD_REGEX.match(s)
            return "πg.NewStr(%s)" % Util::generate_go_str(s)
        end
        @strings.add(s)
        return 'ß' + s
      end

      def resolve_name(writer, name)
        return resolve_global(writer, name)
      end

    end

  end
end

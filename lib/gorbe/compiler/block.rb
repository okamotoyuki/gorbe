require 'set'

module Gorbe
  module Compiler

    NON_WORD_REGEX = Regexp.new('[^A-Za-z0-9_]')

    class Loop
      attr_reader :break_var

      def initialize(break_var)
        @break_var = break_var
      end

    end

    class Block
      attr_reader :free_temps
      attr_reader :used_temps
      attr_reader :root
      attr_reader :checkpoints

      def initialize(parent=nil, name=nil)
        @root = parent ? parent.root : self
        @parent = parent
        @name = name
        @free_temps = Set.new
        @used_temps = Set.new
        @temp_index = 0
        @label_count = 0
        @checkpoints = []
        @loop_stack = []
        # @is_generator
      end

      def bind_var(writer, name, value)
      end

      def gen_label(is_checkpoint=false)
        @label_count += 1
        if is_checkpoint
          @checkpoints.push(@label_count)
        end
        return @label_count
      end

      def alloc_temp(type='*πg.Object')
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

      def free_temp(v)
        @used_temps.delete(v)
        @free_temps.add(v)
      end

      def push_loop(break_var)
        loop = Loop.new(break_var)
        @loop_stack.push(loop)
        return loop
      end

      def pop_loop()
        @loop_stack.pop
      end

      private def resolve_global(writer, name)
        result = alloc_temp
        writer.write_checked_call2(
            result, "πg.ResolveGlobal(πF, %s)" % @root.intern(name))
        return result
      end
    end

    class TopLevel < Block
      attr_reader :strings

      def initialize
        super(nil, '<toplevel>')
        @strings = Set.new
      end

      def bind_var(writer, name, value)
        # TODO : Change it to call write_checked_call2() instead as assignment returns value in Ruby
        writer.write_checked_call1("πF.Globals().SetItem(πF, #{intern(name)}.ToObject(), #{value})")
      end

      def intern(s)
        if s.length > 64 or NON_WORD_REGEX.match(s)
          return "πg.NewStr(%s)" % Util::generate_go_string(s)
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

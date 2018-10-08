module Gorbe
  module Compiler

    # A class for writing Go code
    class Writer

      def initialize(out=StringIO.new())
        @out=out
        @indent_level = 0
      end

      def value
        @out.rewind
        return @out.read
      end

      def indent(n=1)
        @indent_level += n
      end

      def dedent(n=1)
        @indent_level -= n
      end

      def indent_block(n=1)
        indent(n)
        yield if block_given?
        dedent(n)
      end

      def write(code)
        code.lines.each do |line|
          @out.puts("\t" * @indent_level + line)
        end
      end

      def write_block(block, body)
        write('for ; πF.State() >= 0; πF.PopCheckpoint() {')
        indent_block do
          write('switch πF.State() {')
          write('case 0:')
          # block.checkpoints.each do |checkpoint|
          #   write("case #{checkpoint}: goto Label#{checkpoint}")
          # end
          write('default: panic("unexpected function state")')
          write('}')
          indent_block(-1) do
            write(body)
          end
        end
        write('}')
      end

      def write_temp_decls(block)
        all_temps = block.free_temps | block.used_temps
        all_temps.sort { |v1, v2| v1.name <=> v2.name } .each do |temp|
          write("var %s %s\n_ = %s" % [temp.name, temp.type, temp.name])
        end
      end

      def write_checked_call1(call)
        code = <<~EOS
          if πE = #{call}; πE != nil {
            continue
          }
        EOS
        write(code)
      end

      def write_checked_call2(result, call)
        code = <<~EOS
          if #{result.name}, πE = #{call}; πE != nil {
            continue
          }
        EOS
        write(code)
      end
    end

  end
end

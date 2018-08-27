module Gorbe
  module Compiler

    # A class for writing Go code
    class Writer

      def initialize(out=STDOUT)
        @out=out
        @buffer = ''
        @indent_level = 0
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
          @buffer += "\t" * @indent_level + line
        end
      end

      # Generate header of Go code TODO : Consider scope of top level and module
      def write_header(package, script)
        code = <<~EOS
          package #{package}
          import πg "grumpy"
          var Code *πg.Code
          func init() {
          \tCode = πg.NewCode("<module>", #{script}, nil, 0, func(πF *πg.Frame, _ []*πg.Object) (*πg.Object, *πg.BaseException) {
          \t\tvar πR *πg.Object; _ = πR
          \t\tvar πE *πg.BaseException; _ = πE
        EOS
        @buffer += code
      end

      # Generate footer of Go code
      def write_footer(modname)
        code = <<~EOS
          \t\treturn nil, πE
          \t})
          \tπg.RegisterModule(#{modname}, Code)
          }
        EOS
        @buffer += code
      end

      def write_checked_call2(result, call)
        code = <<~EOS
          if #{result}, πE = #{call}; πE != nil {
            continue
          }
        EOS
        write(code)
      end

      def flush
        @out.puts(@buffer)
      end

    end
  end
end

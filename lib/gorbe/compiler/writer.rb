module Gorbe
  module Compiler

    # A class for writing Go code
    class Writer

      def initialize(out=STDOUT)
        @out=out
        @buffer = ""
        @indent_level = 0
      end

      def write(*arg)
        if !block_given?
          Gorbe.logger.error('Template is not given.')
          raise # TODO : Raise an appropriate exception
        end
        code = yield
        @buffer += code
      end

      # Generate header of Go code TODO : Consider scope of top level and module
      def write_header(package, script)
        write(package, script) {
          <<~EOS
            package #{package}
            import πg "grumpy"
            var Code *πg.Code
            func init() {
            \tCode = πg.NewCode("<module>", #{script}, nil, 0, func(πF *πg.Frame, _ []*πg.Object) (*πg.Object, *πg.BaseException) {
            \t\tvar πR *πg.Object; _ = πR
            \t\tvar πE *πg.BaseException; _ = πE
          EOS
        }
      end

      # Generate footer of Go code
      def write_footer(modname)
        write(modname) {
          <<~EOS
            \t\treturn nil, πE
            \t})
            \tπg.RegisterModule(#{modname}, Code)
            }
          EOS
        }
      end

      def flush
        @out.puts(@buffer)
      end

    end
  end
end

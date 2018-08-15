module Gorbe
  module Compiler

    # Generate header of Go code TODO : Consider scope of top level and module
    def generate_header(package, script)
      code = <<~EOS
          package #{package}
          import πg "grumpy"
          var Code *πg.Code
          func init() {
          \tCode = πg.NewCode("<module>", #{script}, nil, 0, func(πF *πg.Frame, _ []*πg.Object) (*πg.Object, *πg.BaseException) {
          \t\tvar πR *πg.Object; _ = πR
          \t\tvar πE *πg.BaseException; _ = πE
      EOS
      puts code
    end
    module_function :generate_header

    # Generate footer of Go code
    def generate_footer(modname)
      code = <<~EOS
          \t\treturn nil, πE
          \t})
          \tπg.RegisterModule(#{modname}, Code)
          }
      EOS
      puts code
    end
    module_function :generate_footer

    # A class for writing Go code
    class Writer
      def initialize
      end
    end
  end
end

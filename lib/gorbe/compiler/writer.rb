module Gorbe
  module Compiler

    class Writer
      def initialize
      end

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

      def generate_footer
        code = <<~EOS
          \t\treturn nil, πE
          \t})
          \tπg.RegisterModule($modname, Code)
          }
        EOS
        puts code
      end
    end

  end
end

require 'gorbe/version'
require 'gorbe/compiler/writer'
require 'gorbe/compiler/visitor'
require 'gorbe/compiler/block'
require 'gorbe/compiler/stmt'
require 'gorbe/compiler/util'

require 'ripper'
require 'logger'
require 'pp'

# A module for transpiling Ruby code to Go code
module Gorbe

  # Logger for Gorbe module
  class << self
    attr_accessor :logger
  end

  # A core class of Gorbe
  class Core
    LOG_LEVEL = {
        :debug => Logger::DEBUG,
        :info => Logger::INFO
    }

    def initialize(log_level=:info)
      Gorbe::logger = Logger.new(STDERR)
      Gorbe::logger.level = LOG_LEVEL[log_level]
    end

    # Compile Ruby code to Go code
    def compile(input=STDIN, output=STDOUT)
      # Ruby code -> Ruby AST
      ast = Ripper.sexp(input.read)
      if Gorbe::logger.level === Logger::DEBUG
        puts('=============== Ruby AST ===============')
        PP.pp(ast, STDERR)
        puts('========================================')
        puts()
      end

      # Ruby AST -> Go code
      return generate_go_code(ast, output)
    end

    # Compile Ruby code in a file to Go code
    def compile_file(filepath, output=STDOUT)
      file = File.open(filepath, 'r') # TODO : Add exception handling
      return compile(file, output)
    end

    # Generate Go code from Ruby AST
    def generate_go_code(ast, output)
      toplevel = Compiler::TopLevel.new
      visitor = Compiler::StatementVisitor.new(toplevel)

      visitor.writer.indent_block do
        visitor.visit(ast)
      end

      writer = Compiler::Writer.new(output)

      package = 'gorbe'   # temporary
      script = '"gorbe"'  # temporary
      header = <<~EOS
        package #{package}
        import πg "grumpy"
        import ρg "gorbe"
        var Code *πg.Code
        func init() {
        \tCode = πg.NewCode("<module>", #{script}, nil, 0, func(πF *πg.Frame, _ []*πg.Object) (*πg.Object, *πg.BaseException) {
        \t\tvar πR *πg.Object; _ = πR
        \t\tvar πE *πg.BaseException; _ = πE
        \t\tπE = ρg.InitGlobalsForRuby(πF)
      EOS
      writer.write(header)

      writer.indent_block(2) do
        toplevel.strings.sort { |v1, v2| v1 <=> v2 } .each do |s|
          writer.write("ß#{s} := πg.InternStr(#{Compiler::Util::generate_go_string(s)})")
        end
        writer.write_temp_decls(toplevel)
        writer.write_block(toplevel, visitor.writer.value)
      end

      modname = '"hello"'
      footer = <<~EOS
        \t\treturn nil, πE
        \t})
        \tπg.RegisterModule(#{modname}, Code)
        }
      EOS
      writer.write(footer)
      writer.out.rewind
      return writer.out
    end
  end

end

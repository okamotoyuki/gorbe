require 'gorbe/version'
require 'gorbe/compiler/writer'
require 'gorbe/compiler/visitor'
require 'gorbe/compiler/block'
require 'gorbe/compiler/stmt'
require 'gorbe/compiler/util'

require 'ripper'
require 'pp'
require 'logger'

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
    def compile(code)
      ast = Ripper.sexp(code)
      Gorbe.logger.debug(ast)
      PP.pp(ast, STDERR) # TODO : Remove this line
      generate_go_code ast
    end

    # Compile Ruby code in a file to Go code
    def compile_file(filepath)
      File.open(filepath, 'r') do |file|
        compile file
      end
    end

    # Generate Go code from Ruby AST
    def generate_go_code(ast)
      toplevel = Compiler::TopLevel.new
      visitor = Compiler::StatementVisitor.new(toplevel)

      visitor.writer.indent_block do
        visitor.visit(ast)
      end

      writer = Compiler::Writer.new(STDOUT)

      package = 'hello'   # temporary
      script = '"hello"'  # temporary
      header = <<~EOS
        package #{package}
        import πg "grumpy"
        var Code *πg.Code
        func init() {
        \tCode = πg.NewCode("<module>", #{script}, nil, 0, func(πF *πg.Frame, _ []*πg.Object) (*πg.Object, *πg.BaseException) {
        \t\tvar πR *πg.Object; _ = πR
        \t\tvar πE *πg.BaseException; _ = πE
      EOS
      writer.write(header)

      writer.indent_block(2) do
        toplevel.strings.sort { |v1, v2| v1 <=> v2 } .each do |s|
          writer.write("ß#{s} := πg.InternStr(#{Compiler::Util::generate_go_str(s)})")
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
    end
  end

end

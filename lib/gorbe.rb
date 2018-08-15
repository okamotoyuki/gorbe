require 'gorbe/version'
require 'gorbe/compiler/writer'
require 'gorbe/compiler/visitor'
require 'gorbe/compiler/block'
require 'gorbe/compiler/stmt'

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
      @writer = Gorbe::Compiler::Writer.new
      Gorbe::logger = Logger.new(STDERR)
      Gorbe::logger.level = LOG_LEVEL[:info]
    end

    # Compile Ruby code to Go code
    def compile(code)
      ast = Ripper.sexp(code)
      Gorbe.logger.debug(ast)
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

      @writer.generate_header('hello', '"hello"') # TODO : Give package and script info
      visitor.visit(ast)
      @writer.generate_footer('"hello"')
    end
  end

end

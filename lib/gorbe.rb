require 'gorbe/version'
require 'gorbe/compiler/writer'
require 'gorbe/compiler/visitor'
require 'gorbe/compiler/block'
require 'gorbe/compiler/stmt'

require 'ripper'
require 'pp'

# A module for transpiling Ruby code to Go code
module Gorbe

  # Debug Gorbe module
  def debug(msg)
    if msg.is_a?(String)
      STDERR.puts '(debug) ' + msg
    else
      STDERR.puts '(debug) '
      PP.pp(msg, STDERR)
    end
  end

  module_function :debug

  # A core class of Gorbe
  class Core
    def initialize
      @writer = Gorbe::Compiler::Writer.new
    end

    # Compile Ruby code to Go code
    def compile(code)
      ast = Ripper.sexp(code)
      Gorbe.debug ast
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

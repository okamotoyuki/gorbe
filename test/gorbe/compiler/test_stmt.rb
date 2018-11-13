require 'minitest/autorun'

require 'gorbe/compiler/stmt'

class StatementVisitorTest < Minitest::Test
  def setup
    block = Gorbe::Compiler::TopLevel.new
    @stmt_visitor = Gorbe::Compiler::StatementVisitor.new(block)
  end

  def teardown
    @stmt_visitor = nil
  end

  # def test_visit_program_negative
  #   node = [:program]
  #   @stmt_visitor.stub(:trace_activity, nil) do
  #     @stmt_visitor.stub(:visit, 1) do
  #       e = assert_raises(Gorbe::Compiler::CompileError) do
  #         @stmt_visitor.visit_program(node)
  #       end
  #       assert_equal('Node: [:program] - Node size must be more than 1.', e.message)
  #     end
  #   end
  # end
  #
  # def test_visit_void_stmt
  #   node = [:void_stmt]
  #   @stmt_visitor.stub(:trace_activity, nil) do
  #     result = @stmt_visitor.visit_void_stmt(node)
  #     assert_nil(result)
  #   end
  # end
end

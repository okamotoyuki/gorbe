require 'minitest/autorun'
require 'logger'
require 'gorbe/compiler/visitor'
require 'gorbe/compiler/error'

class SampleVisitor < Gorbe::Compiler::Visitor
  def visit_stub(node)
    return node[1]
  end
end

class VisitorTest < Minitest::Test
  def setup
    @visitor = SampleVisitor.new(nodetype_map: {stub: 'stub'})
  end

  def teardown
    @gorbe = nil
  end

  def test_visit_empty_node
    node = []
    Gorbe::logger = Logger.new(STDERR)
    assert_raises(Gorbe::Compiler::ParseError) do
      @visitor.visit(node)
    end
  end

  def test_visit_single_node
    node = [:stub, 1]
    result = @visitor.visit(node)
    assert_equal(1, result)
  end

  def test_visit_multiple_node
    node = [[:stub, 1], [:stub, 2], [:stub, 3]]
    result = @visitor.visit(node)
    assert_equal(3, result)
  end
end

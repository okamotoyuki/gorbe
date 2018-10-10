require 'minitest/autorun'

require 'gorbe/compiler/error'
require 'gorbe/compiler/visitor'

class SampleVisitor < Gorbe::Compiler::Visitor
  def visit_stub(node)
    return node[1]
  end
end

class VisitorTest < Minitest::Test
  def setup
    Gorbe::logger = MiniTest::Mock.new.expect(:fatal, nil, [String])
    @visitor = SampleVisitor.new(nodetype_map: {stub: 'stub'})
  end

  def teardown
    @visitor = nil
  end

  def test_visit_empty_node
    node = []
    e = assert_raises(Gorbe::Compiler::ParseError) do
      @visitor.visit(node)
    end
    assert_equal('Node: [] - Node shouldn\'t be empty.', e.message)
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

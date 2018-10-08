require 'minitest/autorun'
require 'gorbe/compiler/visitor'
require 'gorbe/compiler/block'
require 'gorbe/compiler/stmt'
require 'gorbe/compiler/writer'

class StatementVisitorTest < Minitest::Test
  def setup
    toplevel = Gorbe::Compiler::TopLevel.new
    @stmt_visitor = Gorbe::Compiler::StatementVisitor.new(toplevel)
  end

  def teardown
    @gorbe = nil
  end

  def test_visit_program
    node = [:program, [[:void_stmt]]]
    @stmt_visitor.stub(:log_activity, nil) do
      result = @stmt_visitor.visit_program(node)
      assert_nil(result)
    end
  end

  def test_visit_assign
    node = [:assign, [:var_field, [:@ident, 'foo', [1, 0]]], [:@int, '1', [1, 6]]]
    @stmt_visitor.stub(:log_activity, nil) do
      visit_method_mock = MiniTest::Mock.new
      visit_method_mock.expect(:call, 'foo', [node[1]])
      visit_method_mock.expect(:call, '1', [node[2]])

      @stmt_visitor.stub(:visit, visit_method_mock) do
        bind_var_method_mock = MiniTest::Mock.new
        bind_var_method_mock.expect(:call, node[2], [Gorbe::Compiler::Writer, 'foo', '1'])

        @stmt_visitor.block.stub(:bind_var, bind_var_method_mock) do
          result = @stmt_visitor.visit_assign(node)
          assert_equal('1', result)
        end
      end
    end
  end

  def test_visit_ident
    node = [:@ident, 'foo', [1, 0]]
    @stmt_visitor.stub(:log_activity, nil) do
      result = @stmt_visitor.visit_ident(node)
      assert(result == 'foo')
    end
  end

  def test_visit_var_field
    node = [:var_field, [:@ident, 'foo', [1, 0]]]
    @stmt_visitor.stub(:log_activity, nil) do
      result = @stmt_visitor.visit_var_field(node)
      assert(result == 'foo')
      assert_equal('foo', result)
    end
  end

  def test_visit_void_stmt
    node = [:void_stmt]
    @stmt_visitor.stub(:log_activity, nil) do
      result = @stmt_visitor.visit_void_stmt(node)
      assert_nil(result)
    end
  end

end

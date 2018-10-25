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

  def test_visit_program_negative
    node = [:program]
    @stmt_visitor.stub(:log_activity, nil) do
      @stmt_visitor.stub(:visit, 1) do
        e = assert_raises(Gorbe::Compiler::CompileError) do
          @stmt_visitor.visit_program(node)
        end
        assert_equal('Node: [:program] - Node size must be more than 1.', e.message)
      end
    end
  end

  def test_visit_assign_positive
    node = [:assign, [:var_field, [:@ident, 'foo', [1, 0]]], [:@int, '1', [1, 6]]]
    @stmt_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, Gorbe::Compiler::Literal.new('πg.NewInt(1).ToObject()'), [node[2]])
      visit_mock.expect(:call, 'foo', [node[1]])

      @stmt_visitor.stub(:visit, visit_mock) do
        bind_var_mock = MiniTest::Mock.new
        bind_var_mock.expect(:call, node[2], [Gorbe::Compiler::Writer, 'foo', 'πg.NewInt(1).ToObject()'])

        @stmt_visitor.block.stub(:bind_var, bind_var_mock) do
          @stmt_visitor.visit_assign(node)
          assert(true)
        end
      end
    end
  end

  def test_visit_assign_negative
    node = [:assign, [:var_field, [:@ident, 'foo', [1, 0]]]]
    @stmt_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, 'foo', [node[1]])
      visit_mock.expect(:call, '1', [node[2]])

      @stmt_visitor.stub(:visit, visit_mock) do
        bind_var_mock = MiniTest::Mock.new
        bind_var_mock.expect(:call, node[2], [Gorbe::Compiler::Writer, 'foo', '1'])

        @stmt_visitor.block.stub(:bind_var, bind_var_mock) do
          e = assert_raises(Gorbe::Compiler::CompileError) do
            @stmt_visitor.visit_assign(node)
          end
          assert_equal('Node: [:assign, [:var_field, [:@ident, "foo", [1, 0]]]] - Node size must be 3.', e.message)
        end
      end
    end
  end

  def test_visit_ident_positive
    node = [:@ident, 'foo', [1, 0]]
    @stmt_visitor.stub(:log_activity, nil) do
      result = @stmt_visitor.visit_ident(node)
      assert(result == 'foo')
    end
  end

  def test_visit_ident_negative
    node = [:@ident, 'foo']
    @stmt_visitor.stub(:log_activity, nil) do
      e = assert_raises(Gorbe::Compiler::CompileError) do
        @stmt_visitor.visit_ident(node)
      end
      assert_equal('Node: [:@ident, "foo"] - Node size must be 3.', e.message)
    end
  end

  def test_visit_var_field_positive
    node = [:var_field, [:@ident, 'foo', [1, 0]]]
    @stmt_visitor.stub(:log_activity, nil) do
      visit_ident_mock = MiniTest::Mock.new
      visit_ident_mock.expect(:call, 'foo', [node[1]])

      @stmt_visitor.stub(:visit_ident, visit_ident_mock) do
        result = @stmt_visitor.visit_var_field(node)
        assert_equal('foo', result)
      end
    end
  end

  def test_visit_var_field_negative
    node = [:var_field, [:@ident, 'foo', [1, 0]], []]
    @stmt_visitor.stub(:log_activity, nil) do
      visit_ident_mock = MiniTest::Mock.new
      visit_ident_mock.expect(:call, 'foo', [node[1]])

      @stmt_visitor.stub(:visit_ident, visit_ident_mock) do
        e = assert_raises(Gorbe::Compiler::CompileError) do
          @stmt_visitor.visit_var_field(node)
        end
        assert_equal('Node: [:var_field, [:@ident, "foo", [1, 0]], []] - Node size must be 2.', e.message)
      end
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

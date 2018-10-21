require 'minitest/autorun'

require 'gorbe/compiler/visitor'
require 'gorbe/compiler/expr'

class ExprVisitorTest < Minitest::Test
  def setup
    Gorbe::logger = MiniTest::Mock.new.expect(:fatal, nil, [String])
    block = Gorbe::Compiler::TopLevel.new
    stmt_visitor = Gorbe::Compiler::StatementVisitor.new(block)
    @expr_visitor = Gorbe::Compiler::ExprVisitor.new(stmt_visitor)
  end

  def teardown
    @expr_visitor = nil
  end

  def test_visit_binary_positive
    node = [:binary, [:@int, '1', [1, 0]], :+, [:@int, '1', [1, 4]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, Gorbe::Compiler::Literal.new(node[1][1]), [node[1]])
      visit_mock.expect(:call, Gorbe::Compiler::Literal.new(node[3][1]), [node[3]])

      @expr_visitor.stub(:visit, visit_mock) do
        result = @expr_visitor.visit_binary(node)
        assert_equal('πTemp001', result.expr)
      end
    end
  end

  def test_visit_binary_negative
    node = [:binary, [:@int, '1', [1, 0]], :foo, [:@int, '1', [1, 4]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, Gorbe::Compiler::Literal.new(node[1][1]), [node[1]])
      visit_mock.expect(:call, Gorbe::Compiler::Literal.new(node[3][1]), [node[3]])

      @expr_visitor.stub(:visit, visit_mock) do
        e = assert_raises(Gorbe::Compiler::ParseError) do
          result = @expr_visitor.visit_binary(node)
        end
        assert_equal('Node: [:binary, [:@int, "1", [1, 0]], :foo, [:@int, "1", [1, 4]]] ' +
                         '- The operator \'foo\' is not supported. ' +
                         'Please contact us via https://github.com/okamotoyuki/gorbe/issues.', e.message)
      end
    end
  end

  def test_visit_unary_positive
    node = [:unary, :-@, [:@int, '123', [1, 1]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, Gorbe::Compiler::Literal.new(node[2][1]), [node[2]])

      @expr_visitor.stub(:visit, visit_mock) do
        result = @expr_visitor.visit_unary(node)
        assert_equal('πTemp001', result.expr)
      end
    end
  end

  def test_visit_unary_negative
    node = [:unary, :foo, [:@int, '123', [1, 1]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, Gorbe::Compiler::Literal.new(node[2][1]), [node[2]])

      @expr_visitor.stub(:visit, visit_mock) do
        e = assert_raises(Gorbe::Compiler::ParseError) do
          result = @expr_visitor.visit_unary(node)
        end
        assert_equal('Node: [:unary, :foo, [:@int, "123", [1, 1]]] ' +
                         '- The operator \'foo\' is not supported. ' +
                         'Please contact us via https://github.com/okamotoyuki/gorbe/issues.', e.message)
      end
    end
  end

  def test_visit_var_ref_positive
    node = [:var_ref, [:@kw, 'true', [1, 0]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, node[1][1], [node[1]])

      @expr_visitor.stub(:visit, visit_mock) do
        resolve_name_mock = MiniTest::Mock.new
        resolve_name_mock
            .expect(:call, Gorbe::Compiler::TempVar.new(name: 'πTemp001'), [Gorbe::Compiler::Writer, node[1][1]])

        @expr_visitor.block.stub(:resolve_name, resolve_name_mock) do
          result = @expr_visitor.visit_var_ref(node)
          assert_equal('πTemp001', result.expr)
        end
      end
    end
  end

  def test_visit_var_ref_negative
    node = [:var_ref, [:@kw, nil, [1, 0]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, node[1][1], [node[1]])

      @expr_visitor.stub(:visit, visit_mock) do
        resolve_name_mock = MiniTest::Mock.new
        resolve_name_mock
            .expect(:call, Gorbe::Compiler::TempVar.new(name: 'πTemp001'), [Gorbe::Compiler::Writer, node[1][1]])

        @expr_visitor.block.stub(:resolve_name, resolve_name_mock) do
          e = assert_raises(Gorbe::Compiler::ParseError) do
            result = @expr_visitor.visit_var_ref(node)
          end
          assert_equal('Node: [:var_ref, [:@kw, nil, [1, 0]]] - Keyword mult not be nil.', e.message)
        end
      end
    end
  end

  def test_visit_num_positive
    node = [:@int, '1', [1, 0]]
    @expr_visitor.stub(:log_activity, nil) do
      result = @expr_visitor.visit_num(node)
      assert_equal("πg.NewInt(#{node[1]}).ToObject()", result.expr)
    end
  end

  def test_visit_num_negative
    node = [:@int, 'a', [1, 0]]
    @expr_visitor.stub(:log_activity, nil) do
      e = assert_raises(ArgumentError) do
        @expr_visitor.visit_num(node)
      end
      assert_equal('invalid value for Integer(): "a"', e.message)
    end
  end

  def test_visit_tstring_content
    node = [:@tstring_content, 'this is a string expression\\n', [1, 1]]
    @expr_visitor.stub(:log_activity, nil) do
      result = @expr_visitor.visit_tstring_content(node)
      assert_equal('πg.NewStr("this is a string expression\\n").ToObject()', result.expr)
    end
  end

  def test_visit_tstring_negative
    node = [:@tstring_content, [], [1, 1]]
    @expr_visitor.stub(:log_activity, nil) do
      e = assert_raises(TypeError) do
        @expr_visitor.visit_tstring_content(node)
      end
      assert_equal('no implicit conversion of Array into String', e.message)
    end
  end

  def test_visit_array_positive
    node = [:array, [[:@int, '1', [1, 1]], [:@int, '2', [1, 4]], [:@int, '3', [1, 7]]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_sequential_elements_mock = MiniTest::Mock.new
      visit_sequential_elements_mock
          .expect(:call, Gorbe::Compiler::TempVar.new(block: @expr_visitor.block, name: 'πTemp001', type: '[]*πg.Object'), [Array])

      @expr_visitor.stub(:visit_sequential_elements, visit_sequential_elements_mock) do
        result = @expr_visitor.visit_array(node)
        assert_equal('*πg.Object', result.type)
      end
    end
  end

  def test_visit_array_negative
    node = [:array, 1, [:@int, '2', [1, 4]], [:@int, '3', [1, 7]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_sequential_elements_mock = MiniTest::Mock.new
      visit_sequential_elements_mock
          .expect(:call, Gorbe::Compiler::TempVar.new(block: @expr_visitor.block, name: 'πTemp001', type: '[]*πg.Object'), [Array])

      @expr_visitor.stub(:visit_sequential_elements, visit_sequential_elements_mock) do
        e = assert_raises(MockExpectationError) do
          @expr_visitor.visit_array(node)
        end
        assert_equal('mocked method :call called with unexpected arguments [1]', e.message)
      end
    end
  end

  def test_visit_hash_positive
    node = [:hash, [:assoclist_from_args, [[:assoc_new, [:@int, '1', [1, 2]], [:@int, '2', [1, 7]]]]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, nil, [node[1], Hash])

      @expr_visitor.stub(:visit, visit_mock) do
        result = @expr_visitor.visit_hash(node)
        assert_equal('*πg.Object', result.type)
      end
    end
  end

  def test_visit_hash_negative
    node = [:hash, [:assoclist_from_args, [[:assoc_new, [:@int, '1', [1, 2]], [:@int, '2', [1, 7]]]]], [:assoclist_from_args]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, nil, [node[1], Hash])

      @expr_visitor.stub(:visit, visit_mock) do
        e = assert_raises(Gorbe::Compiler::ParseError) do
          @expr_visitor.visit_hash(node)
        end
        assert_equal('Node: [:hash, [:assoclist_from_args, [[:assoc_new, [:@int, "1", [1, 2]], ' +
                         '[:@int, "2", [1, 7]]]]], [:assoclist_from_args]] ' +
                         '- Node size must be 2.', e.message)
      end
    end
  end

end

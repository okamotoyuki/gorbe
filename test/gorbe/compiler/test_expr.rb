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
        resolve_name_mock.expect(:call, Gorbe::Compiler::TempVar.new(name: 'πTemp001'), [Gorbe::Compiler::Writer, node[1][1]])

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
        resolve_name_mock.expect(:call, Gorbe::Compiler::TempVar.new(name: 'πTemp001'), [Gorbe::Compiler::Writer, node[1][1]])

        @expr_visitor.block.stub(:resolve_name, resolve_name_mock) do
          e = assert_raises(Gorbe::Compiler::ParseError) do
            result = @expr_visitor.visit_var_ref(node)
          end
          assert_equal('Node: [:var_ref, [:@kw, nil, [1, 0]]] - Keyword mult not be nil.', e.message)
        end
      end
    end
  end

  def test_visit_num
    node = [:@int, '1', [1, 0]]
    @expr_visitor.stub(:log_activity, nil) do
      result = @expr_visitor.visit_num(node)
      assert_equal("πg.NewInt(#{node[1]}).ToObject()", result.expr)
    end
  end

  def test_visit_string_literal
    node = [:string_literal, [:string_content, [:@tstring_content, 'this is a string expression\\n', [1, 1]]]]
    @expr_visitor.stub(:log_activity, nil) do
      visit_mock = MiniTest::Mock.new
      visit_mock.expect(:call, node[1][1], [node[1]])

      @expr_visitor.stub(:visit, visit_mock) do
        intern_mock = MiniTest::Mock.new
        intern_mock.expect(:call, 'πg.NewStr("this is a string expression\\\\n")', [node[1][1]])

        @expr_visitor.block.root.stub(:intern, intern_mock) do
          result = @expr_visitor.visit_string_literal(node)
          assert_equal('πg.NewStr("this is a string expression\\\\n").ToObject()', result.expr)
        end
      end
    end
  end

end

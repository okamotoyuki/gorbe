require 'minitest/autorun'
require 'gorbe'

class CoreTest < Minitest::Test
  def setup
    @gorbe = Gorbe::Core.new(:debug)
  end

  def teardown
    @gorbe = nil
  end

  # A method for getting test code path from test method name
  def get_test_path_from_method(method_name)
    # e.g. "test_parser_0_category_1_test" -> "0_category_1_test"
    method_name.slice!('test_core_')

    # e.g. "0_category_1_test" -> ["0", "category_1_test"]
    category_id = method_name.slice!(/^\d+\_/).chop

    # e.g. "category_1_test" -> ["category", "1_test"]
    category_name = method_name.slice!(/^[a-zA-Z]+\_/).chop

    test_id = category_id + '.' + method_name.slice!(/^\d+\_/).chop
    test_name = method_name

    './test/sample/' + category_id + '_' + category_name + '/' +
      test_id + '_' + test_name + '.rb'
  end

  def test_core_0_toplevel_1_identifier
    test_path = get_test_path_from_method(__method__.to_s)
    @gorbe.compile_file(test_path)
    # TODO : Add assert function here
  end

  def test_core_0_toplevel_2_comment
    test_path = get_test_path_from_method(__method__.to_s)
    @gorbe.compile_file(test_path)
    # TODO : Add assert function here
  end

  def test_core_0_toplevel_3_heredoc
    test_path = get_test_path_from_method(__method__.to_s)
    @gorbe.compile_file(test_path)
    # TODO : Add assert function here
  end

  def test_core_0_toplevel_4_reserved_word
    test_path = get_test_path_from_method(__method__.to_s)
    @gorbe.compile_file(test_path)
    # TODO : Add assert function here
  end

  def test_core_0_toplevel_5_expression
    test_path = get_test_path_from_method(__method__.to_s)
    @gorbe.compile_file(test_path)
    # TODO : Add assert function here
  end

  def test_core_0_toplevel_99_print
    test_path = get_test_path_from_method(__method__.to_s)
    @gorbe.compile_file(test_path)
    # TODO : Add assert function here
  end
end

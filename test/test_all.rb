require 'minitest/autorun'
require 'gorbe'

class CoreTest < Minitest::Test
  def setup
    @gorbe = Gorbe::Core.new(:debug)
  end

  def teardown
    @gorbe = nil
  end

  # Define test methods
  Dir.glob('./test/ruby_samples/**/*').each do |test_path|
    next unless test_path.end_with? '.rb'

    test_name = "test_#{test_path
                            .gsub('./test/ruby_samples/', '')
                            .gsub('.rb', '')
                            .gsub('/', '_')}"
    define_method test_name do
      @gorbe.compile_file(test_path)
      # TODO : Add assert function here
    end
  end
end

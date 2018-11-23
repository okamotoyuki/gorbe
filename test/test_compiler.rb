require 'minitest/autorun'
require 'gorbe'

class CompilerTest < Minitest::Test
  def setup
    @gorbe = Gorbe::Core.new(:info)

    # Create Go package directory
    `mkdir -p build/gorbe`
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
      # Compile Ruby code
      output = @gorbe.compile_file(test_path, StringIO.new)
      return 1 if output.nil?  # Compile failed

      # Create Go file
      begin
        File.open('build/gorbe/module.go', 'w') do |file|
          file.write(output.read)
          file.close
        end
      rescue => error
        puts error
      end

      # Run Go code
      actual = `go run go/main.go`
      expected = `ruby #{test_path}`
      assert_equal(expected, actual)
    end
  end
end

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'gorbe'

Rake::TestTask.new do |test|
  test.libs << 'test'
end

desc 'Run test'
task :default => :test

private def compile(filepath, output)
  gorbe = Gorbe::Core.new(:info)
  unless filepath.nil? then
    output = gorbe.compile_file(filepath, output)
  else
    output = gorbe.compile(STDIN, output)
  end
  output.rewind
  return output
end

desc 'Compile Ruby code to Go code'
task :compile, :filepath do |task, args|
  compile(args[:filepath], STDOUT)
end

desc 'Compile Ruby code to Go code and run it immediately'
task :run, :filepath do |task, args|
  # Create Go package directory
  sh 'mkdir -p build/gorbe'

  # Compile Ruby code
  output = compile(args[:filepath], StringIO.new)
  return 1 if output.nil?  # Compile failed

  # Create Go file
  go_file = File.open('build/gorbe/module.go', 'w')
  go_file.write(output.read)
  go_file.close

  # Run Go code
  sh 'go run go/main.go'
end

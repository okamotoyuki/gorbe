require 'bundler/gem_tasks'
require 'rake/testtask'
require 'gorbe'

Rake::TestTask.new do |test|
  test.libs << 'test'
  test.test_files = Dir[ 'test/**/test_*.rb' ]
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
  return output
end

desc 'Compile Ruby code to Go code'
task :compile, :filepath do |task, args|
  compile(args[:filepath], STDOUT)
end

desc 'Initialize environment'
task :init do |task, args|
  ENV['GOPATH'].to_s.split(':').each do |env|
    if env.end_with?('/grumpy/build')
      sh "cp go/src/grumpy/export.go #{env}/src/grumpy"
    end
  end
end

desc 'Compile Ruby code to Go code and run it immediately'
task :run, :filepath do |task, args|
  # Create Go package directory
  sh 'mkdir -p build/gorbe'

  # Compile Ruby code
  output = compile(args[:filepath], StringIO.new)
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
  sh 'go run go/main.go'
end

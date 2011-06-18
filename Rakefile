begin
  require 'rubygems'
  require 'rubygems/package_task'

  spec = eval(File.read("statsd.gemspec"), nil, 'statsd.gemspec')

  Gem::PackageTask.new(spec).define
rescue LoadError
  desc "You gotta have rubygems to make the gem"
  task(:gem) { abort "install rubygems to build this gem"}
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new
rescue LoadError
  desc "install rspec to run tests"
  task(:spec) { abort "install rspec to run the tests" }
end
task :default => :spec

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |spec|
    spec.libs << 'lib' << 'spec'
    spec.pattern = 'spec/**/*_spec.rb'
    spec.verbose = true
  end
rescue LoadError
  desc "install rcov to generate test coverage reports"
  task(:rcov) { abort "install rcov to analyze test coverage"}
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  desc "install yard to generate documentation"
  task(:yard) { abort "install yard to generate docs"}
end


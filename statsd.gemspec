$:.unshift(File.expand_path('../lib', __FILE__))
require 'statsd/version'

Gem::Specification.new do |gem|
  gem.name = "statsd"
  gem.version = Statsd::VERSION
  gem.homepage = "http://github.com/reinh/statsd"

  gem.license = "MIT"
  gem.summary = %Q{A Statsd client in Ruby}
  gem.description =<<-D
statsd is a ruby client for etsy's statsd metrics collector.

This statsd implementation includes a command line client for easy testing, and
a rack middleware for easy integration with your web application.

* https://github.com/etsy/statsd
* http://codeascraft.etsy.com/2011/02/15/measure-anything-measure-everything/
D
  gem.email = "rein@phpfog.com"
  gem.authors = ["Rein Henrichs", "Daniel DeLeo"]

  gem.executables = %w[statsd-client]
  gem.files = %w(LICENSE.txt README.rdoc) + Dir.glob("lib/**/*")

  gem.add_development_dependency "minitest", ">= 0"
  gem.add_development_dependency "yard", "~> 0.6.0"
  gem.add_development_dependency "rcov", ">= 0"
end


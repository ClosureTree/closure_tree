$:.push File.expand_path("../lib", __FILE__)
require "closure_tree/version"

Gem::Specification.new do |gem|
  gem.name        = "closure_tree"
  gem.version     = ::ClosureTree::VERSION
  gem.authors     = ["Matthew McEachen"]
  gem.email       = ["matthew-github@mceachen.org"]
  gem.homepage    = "http://matthew.mceachen.us/closure_tree"

  gem.summary = %q{Easily and efficiently make your ActiveRecord model support hierarchies}
  gem.description = %q{Easily and efficiently make your ActiveRecord model support hierarchies}

  gem.files = Dir["lib/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.add_runtime_dependency 'activerecord', '>= 3.0.0'
  gem.add_runtime_dependency 'with_advisory_lock' # <- to prevent duplicate roots

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rails' # FIXME: just for rspec fixture support (!!)
  gem.add_development_dependency 'rspec-rails' # FIXME: just for rspec fixture support (!!)
  gem.add_development_dependency 'mysql2'
  gem.add_development_dependency 'pg'
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'uuidtools'
  gem.add_development_dependency 'strong_parameters'
  # TODO: gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
end

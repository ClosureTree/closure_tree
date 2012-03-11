$:.push File.expand_path("../lib", __FILE__)
require "closure_tree/version"

Gem::Specification.new do |s|
  s.name        = "closure_tree"
  s.version     = ::ClosureTree::VERSION
  s.authors     = ["Matthew McEachen"]
  s.email       = ["matthew-github@mceachen.org"]
  s.homepage    = "http://matthew.mceachen.us/closure_tree"

  s.summary = %q{Hierarchies for ActiveRecord models using a Closure Tree storage algorithm}
  s.description = <<-desc
    A mostly-API-compatible replacement for the acts_as_tree and awesome_nested_set gems,
    but with much better mutation performance thanks to the Closure Tree storage algorithm
  desc
  s.files = Dir["lib/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.add_runtime_dependency 'activerecord', '>= 3.0.0'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rails' # FIXME: just for rspec fixture support (!!)
  s.add_development_dependency 'rspec-rails' # FIXME: just for rspec fixture support (!!)
  s.add_development_dependency 'mysql2'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'sqlite3'
  # TODO: gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
end

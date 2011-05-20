# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "closure-tree/version"

Gem::Specification.new do |s|
  s.name        = "closure_tree"
  s.version     = ClosureTree::VERSION
  # TODO: s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matthew McEachen"]
  s.email       = ["matthew-closuretree@mceachen.org"]
  s.homepage    = "http://matthew.mceachen.us/blog/tags/closure-tree"
  s.summary     = %q{Hierarchical tagging for ActiveRecord models using a Closure Tree storage algorithm}
  s.description = <<desc
  A mostly-API-compatible replacement for the acts_as_tree and awesome_nested_set gems,
  but with much better mutation performance thanks to the Closure Tree storage algorithm
desc

  s.files = Dir.glob("lib/**/*") + %w(MIT-LICENSE README.md CHANGELOG)
  # s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  # s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_runtime_dependency 'activerecord', '>= 3.0.0'
end

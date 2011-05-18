# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "closure-tree/version"

Gem::Specification.new do |s|
  s.name        = "closure-tree"
  s.version     = Closure::Tree::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matthew McEachen"]
  s.email       = ["matthew-closuretree@mceachen.org"]
  s.homepage    = "http://matthew.mceachen.us/blog/tags/closure-tree"
  s.summary     = %q{Hierarchical tagging for ActiveRecord models using a Closure Tree storage algorithm}
  s.description = %q{A mostly-API-compatible replacement for the acts_as_tree and awesome_nested_set gems, but with much better mutation performance thanks to the Closure Tree storage algorithm.}

  s.rubyforge_project = "closure-tree"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

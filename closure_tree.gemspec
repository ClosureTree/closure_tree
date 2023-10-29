# frozen_string_literal: true

require 'English'
require_relative 'lib/closure_tree/version'

Gem::Specification.new do |gem|
  gem.name        = 'closure_tree'
  gem.version     = ::ClosureTree::VERSION
  gem.authors     = ['Matthew McEachen', 'Abdelkader Boudih']
  gem.email       = %w[matthew+github@mceachen.org terminale@gmail.com]
  gem.homepage    = 'https://github.com/ClosureTree/closure_tree/'

  gem.summary     = 'Easily and efficiently make your ActiveRecord model support hierarchies'
  gem.description = gem.summary
  gem.license     = 'MIT'

  gem.files = `git ls-files`.split($INPUT_RECORD_SEPARATOR).reject do |f|
    f.match(/^(spec|img|gemfiles)/)
  end

  gem.test_files = gem.files.grep(%r{^spec/})
  gem.required_ruby_version = '>= 2.7.7'

  gem.add_runtime_dependency 'activerecord', '>= 6.1.0'
  gem.add_runtime_dependency 'with_advisory_lock', '>= 5.0.0'

  gem.add_development_dependency 'appraisal'
  gem.add_development_dependency 'database_cleaner'
  gem.add_development_dependency 'generator_spec'
  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'minitest-reporters'
  gem.add_development_dependency 'parallel'
  gem.add_development_dependency 'rspec-instafail'
  gem.add_development_dependency 'rspec-rails'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'timecop'
  # gem.add_development_dependency 'byebug'
  # gem.add_development_dependency 'ruby-prof' # <- don't need this normally.
end

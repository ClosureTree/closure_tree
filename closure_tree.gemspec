# frozen_string_literal: true

require_relative 'lib/closure_tree/version'

Gem::Specification.new do |gem|
  gem.name        = 'closure_tree'
  gem.version     = ClosureTree::VERSION
  gem.authors     = ['Matthew McEachen', 'Abdelkader Boudih']
  gem.email       = %w[matthew+github@mceachen.org terminale@gmail.com]
  gem.homepage    = 'https://github.com/ClosureTree/closure_tree/'

  gem.summary     = %q(Easily and efficiently make your ActiveRecord model support hierarchies)
  gem.license     = 'MIT'

  gem.metadata = {
    'bug_tracker_uri'   => "https://github.com/ClosureTree/closure_tree/issues",
    'changelog_uri'     => "https://github.com/ClosureTree/closure_tree/blob/master/CHANGELOG.md",
    'documentation_uri' => "https://www.rubydoc.info/gems/closure_tree/#{gem.version}",
    'homepage_uri'      => "https://closuretree.github.io/closure_tree/",
    'source_code_uri'   => "https://github.com/ClosureTree/closure_tree",
  }

  gem.files         = `git ls-files`.split($/).reject do |f|
    f.match(%r{^(test|img|gemfiles)})
  end

  gem.test_files  = gem.files.grep(%r{^test/})
  gem.required_ruby_version = '>= 3.3.0'

  gem.add_runtime_dependency 'activerecord', '>= 7.1.0'
  gem.add_runtime_dependency 'with_advisory_lock', '>= 6.0.0'

  gem.add_development_dependency 'appraisal'
  gem.add_development_dependency 'database_cleaner'
  gem.add_development_dependency 'parallel'
  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'minitest-reporters'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'timecop'
  # gem.add_development_dependency 'byebug'
  # gem.add_development_dependency 'ruby-prof' # <- don't need this normally.
end

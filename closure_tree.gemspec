$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'closure_tree/version'

Gem::Specification.new do |gem|
  gem.name        = 'closure_tree'
  gem.version     = ::ClosureTree::VERSION
  gem.authors     = ['Matthew McEachen']
  gem.email       = ['matthew-github@mceachen.org']
  gem.homepage    = 'http://mceachen.github.io/closure_tree/'

  gem.summary     = %q(Easily and efficiently make your ActiveRecord model support hierarchies)
  gem.description = gem.summary
  gem.license     = 'MIT'

  gem.files         = `git ls-files`.split($/).reject do |f|
    f.match(%r{^(spec|img|gemfiles)})
  end

  gem.test_files  = gem.files.grep(%r{^spec/})
  gem.required_ruby_version = '>= 2.0.0'

  gem.add_runtime_dependency 'activerecord', '>= 4.2.10'
  gem.add_runtime_dependency 'with_advisory_lock', '>= 4.0.0'

  gem.add_development_dependency 'appraisal'
  gem.add_development_dependency 'database_cleaner'
  gem.add_development_dependency 'generator_spec'
  gem.add_development_dependency 'parallel'
  gem.add_development_dependency 'rspec-instafail'
  gem.add_development_dependency 'rspec-rails'
  gem.add_development_dependency 'timecop'
  # gem.add_development_dependency 'byebug'
  # gem.add_development_dependency 'ruby-prof' # <- don't need this normally.
end

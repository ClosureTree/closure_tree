$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'closure_tree/version'

Gem::Specification.new do |gem|
  gem.name        = 'closure_tree'
  gem.version     = ::ClosureTree::VERSION
  gem.authors     = ['Matthew McEachen']
  gem.email       = ['matthew-github@mceachen.org']
  gem.homepage    = 'http://mceachen.github.io/closure_tree/'

  gem.summary = %q(Easily and efficiently make your ActiveRecord model support hierarchies)
  gem.description = gem.summary
  gem.license = 'MIT'

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.test_files    = gem.files.grep(%r{^spec/})

  gem.add_runtime_dependency 'activerecord', '>= 3.2.0'
  gem.add_runtime_dependency 'with_advisory_lock', '>= 0.0.9' # <- to prevent duplicate roots

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rspec-instafail'
  gem.add_development_dependency 'rspec-rails' # FIXME: for rspec-rails and rspec fixture support
  gem.add_development_dependency 'mysql2'
  gem.add_development_dependency 'pg'
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'uuidtools'
  gem.add_development_dependency 'database_cleaner'
  gem.add_development_dependency 'appraisal', '~> 1.0'

  # gem.add_development_dependency 'ruby-prof' # <- don't need this normally.
  # TODO: gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
end

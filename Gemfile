source "http://rubygems.org"
gemspec

group :test, :development do
  if RUBY_VERSION < '1.9'
    gem "ruby-debug", ">= 0.10.3"
  end
  gem 'rake'
  gem 'rails'
  gem 'rack'
  gem 'yard'
  gem 'mysql2'
  gem 'pg'
  gem 'sqlite3', :platform => :ruby
  gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
  gem 'rspec-rails'
  # gem 'shoulda'
  # gem 'guard-rspec'
end

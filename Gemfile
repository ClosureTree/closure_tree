source "http://rubygems.org"

group :test, :development do
  if RUBY_VERSION < '1.9'
    gem "ruby-debug", ">= 0.10.3"
  end
  gem 'rails'
  gem 'rack', '1.3.3' # See http://stackoverflow.com/questions/7624661/rake-already-initialized-constant-warning
  gem 'yard'
  gem 'mysql2'
  gem 'pg'
  gem 'sqlite3', :platform => :ruby
  gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
  gem 'rspec-rails'
  gem 'shoulda'
#  gem 'guard-rspec'
end

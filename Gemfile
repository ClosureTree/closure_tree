source "http://rubygems.org"

gem 'rails'
gem 'rack', '1.3.3' # See http://stackoverflow.com/questions/7624661/rake-already-initialized-constant-warning
gem 'yard'
gem 'mysql2'
gem 'pg'
gem 'sqlite3', :platform => :ruby
gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby

#if RUBY_VERSION < '1.9'
#  gem "ruby-debug", ">= 0.10.3"
#end

group :test, :development do
  gem 'rspec-rails', '>= 2.6.0'
#  gem 'guard-rspec'
end

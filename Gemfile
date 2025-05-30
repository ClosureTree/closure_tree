# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'railties'
gem 'with_advisory_lock', github: 'closuretree/with_advisory_lock'

gem 'activerecord', "~> #{ENV['RAILS_VERSION'] || '8.0'}.0"

platforms :ruby, :truffleruby do
  # Database adapters
  gem 'mysql2'
  gem 'pg'
  gem 'sqlite3'
end

platform :jruby do
  # JRuby-specific gems
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'activerecord-jdbcsqlite3-adapter'
end

# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'dotenv'
gem 'railties'
gem 'with_advisory_lock', '>= 7'

gem 'activerecord', "~> #{ENV['RAILS_VERSION'] || '8.0'}"

platforms :mri, :truffleruby do
  # Database adapters
  gem 'mysql2'
  gem 'pg'
  gem 'sqlite3'
end

# Testing gems
group :test do
  gem 'maxitest'
  gem 'mocha'
end

# Development gems
group :development do
  gem 'rubocop', require: false
end

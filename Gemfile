# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'dotenv'
gem 'with_advisory_lock', '>= 7'

rails_version = ENV['RAILS_VERSION'] || '8.0'
gem 'activerecord', "~> #{rails_version}"
gem 'railties', "~> #{rails_version}"

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

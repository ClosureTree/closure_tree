# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'dotenv'
gem 'railties'
gem 'with_advisory_lock', github: 'closuretree/with_advisory_lock'

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

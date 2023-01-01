# frozen_string_literal: true


require 'database_cleaner'
require 'closure_tree/test/matcher'
require 'tmpdir'
require 'timecop'
require 'forwardable'
require 'parallel'

require 'active_record'
require 'active_support/core_ext/array'


# Start Simplecov
if RUBY_ENGINE == 'ruby'
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
  end
end

ActiveRecord::Base.configurations = {
  default_env: {
    url: ENV.fetch('DATABASE_URL', "sqlite3::memory:"),
    properties: { allowPublicKeyRetrieval: true } # for JRuby madness
  }
}

# Configure ActiveRecord
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s
ActiveRecord::Base.establish_connection

def env_db
  @env_db ||= if ActiveRecord::Base.respond_to?(:connection_db_config)
                ActiveRecord::Base.connection_db_config.adapter
              else
                ActiveRecord::Base.connection_config[:adapter]
              end.to_sym
end

# Use in specs to skip some tests
def sqlite?
  env_db == :sqlite3
end

# Configure RSpec
RSpec.configure do |config|
  config.include ClosureTree::Test::Matcher

  config.color = true
  config.fail_fast = false

  config.order = :random

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  DatabaseCleaner.strategy = :truncation
  DatabaseCleaner.allow_remote_database_url = true

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  # disable monkey patching
  # see: https://relishapp.com/rspec/rspec-core/v/3-8/docs/configuration/zero-monkey-patching-mode
  config.disable_monkey_patching!

  if sqlite?
    config.before(:suite) do
      ENV['FLOCK_DIR'] = Dir.mktmpdir
    end

    config.after(:suite) do
      FileUtils.remove_entry_secure ENV['FLOCK_DIR']
    end
  end
end

# Configure parallel specs
Thread.abort_on_exception = true

# Configure advisory_lock
# See: https://github.com/ClosureTree/with_advisory_lock
ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

ActiveRecord::Base.connection.recreate_database("closure_tree_test") unless sqlite?
puts "Testing with #{env_db} database, ActiveRecord #{ActiveRecord.gem_version} and #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION} as #{RUBY_VERSION}"
# Require our gem
require 'closure_tree'

# Load test helpers
require_relative 'support/schema'
require_relative 'support/models'
require_relative 'support/helpers'
require_relative 'support/exceed_query_limit'
require_relative 'support/query_counter'

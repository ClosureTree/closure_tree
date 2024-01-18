# frozen_string_literal: true

require 'active_record'
require 'minitest'
require 'minitest/autorun'
require 'database_cleaner'
require 'support/query_counter'
require 'parallel'

puts "Using ActiveRecord #{ActiveRecord.gem_version} and #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION} as #{RUBY_VERSION}"

primary_database_url = ENV['DATABASE_URL'].presence || "sqlite3:///tmp/closure_tree_test"
secondary_database_url = ENV['SECONDARY_DATABASE_URL'].presence || "sqlite3:///tmp/closure_tree_test-s"

puts "Using primary database #{primary_database_url}"
puts "Using secondary database #{secondary_database_url}"

ActiveRecord::Base.configurations = {
  default_env: {
    primary: {
      url: primary_database_url,
      properties: { allowPublicKeyRetrieval: true } # for JRuby madness
    },
    secondary: {
      url: secondary_database_url,
      properties: { allowPublicKeyRetrieval: true } # for JRuby madness
    }
  }
}

ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

def env_db
  @env_db ||= ActiveRecord::Base.connection_db_config.adapter.to_sym
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s

# Use in specs to skip some tests
def sqlite?
  env_db == :sqlite3
end


DatabaseCleaner.strategy = :truncation
DatabaseCleaner.allow_remote_database_url = true

module Minitest
  class Spec
    include QueryCounter

    before :each do
      ENV['FLOCK_DIR'] = Dir.mktmpdir
      DatabaseCleaner.start
    end

    after :each do
      FileUtils.remove_entry_secure ENV['FLOCK_DIR']
      DatabaseCleaner.clean
    end
  end
end

# Configure parallel tests
Thread.abort_on_exception = true

require 'closure_tree'
begin
  ActiveRecord::Base.establish_connection(:primary)
rescue
  ActiveRecord::Tasks::DatabaseTasks.create_current('primary')
end

begin
  ActiveRecord::Base.establish_connection(:secondary)
rescue
  ActiveRecord::Tasks::DatabaseTasks.create_current('secondary')
end

require_relative '../spec/support/schema'
require_relative '../spec/support/models'

puts "Testing with #{env_db} database"

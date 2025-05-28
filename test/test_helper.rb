# frozen_string_literal: true

require 'logger'
require 'erb'
require 'active_record'
require 'with_advisory_lock'
require 'tmpdir'
require 'securerandom'
require 'minitest'
require 'minitest/autorun'
require 'database_cleaner'
require 'support/query_counter'
require 'parallel'
require 'timecop'

# Configure the database based on environment
database_url = ENV['DB_ADAPTER'] || ENV['DATABASE_URL'] || "sqlite3:///:memory:"

ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

# Parse database URL and establish connection
if database_url.start_with?('sqlite3://')
  # SQLite needs special handling
  if database_url == 'sqlite3:///:memory:'
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
  else
    # Create a temporary database file
    db_file = File.join(Dir.tmpdir, "closure_tree_test_#{SecureRandom.hex}.sqlite3")
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: db_file)
  end
else
  # For MySQL and PostgreSQL, use the URL directly
  ActiveRecord::Base.establish_connection(database_url)
end

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

ActiveRecord::Base.connection.recreate_database('closure_tree_test') unless sqlite?
puts "Testing with #{env_db} database, ActiveRecord #{ActiveRecord.gem_version} and #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION} as #{RUBY_VERSION}"

DatabaseCleaner.strategy = :truncation

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

class ActiveSupport::TestCase
  setup do
    DatabaseCleaner.start
  end
  
  teardown do
    DatabaseCleaner.clean
  end

  def exceed_query_limit(num, &block)
    counter = QueryCounter.new
    ActiveSupport::Notifications.subscribed(counter.to_proc, 'sql.active_record', &block)
    assert counter.query_count <= num, "Expected to run maximum #{num} queries, but ran #{counter.query_count}"
  end

  class QueryCounter
    attr_reader :query_count

    def initialize
      @query_count = 0
    end

    def to_proc
      lambda(&method(:callback))
    end

    def callback(name, start, finish, message_id, values)
      @query_count += 1 unless %w(CACHE SCHEMA).include?(values[:name])
    end
  end
end

# Configure parallel tests
Thread.abort_on_exception = true

# Configure advisory_lock
# See: https://github.com/ClosureTree/with_advisory_lock
ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

require 'closure_tree'
require_relative 'support/schema'
require_relative 'support/models'

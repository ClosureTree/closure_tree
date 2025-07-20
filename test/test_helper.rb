# frozen_string_literal: true

require 'securerandom'
ENV['RAILS_ENV'] = 'test'
ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

require 'dotenv'
Dotenv.load

require_relative 'dummy/config/environment'
require 'rails/test_help'
require 'with_advisory_lock'

require 'minitest/autorun'
require 'database_cleaner'
require 'database_cleaner/active_record'
require 'support/query_counter'
require 'parallel'
require 'timecop'

# Configure parallel tests
Thread.abort_on_exception = true

class ActiveSupport::TestCase
  # Configure DatabaseCleaner
  self.use_transactional_tests = false
  parallelize(workers: 1)

  def self.startup
    # Validate environment variables when tests actually start running
    %w[DATABASE_URL_PG DATABASE_URL_MYSQL].each do |var|
      warn "Warning: Missing environment variable: #{var}" if ENV[var].nil? || ENV[var].empty?
    end
  end

  setup do
    # Configure DatabaseCleaner for each database connection
    DatabaseCleaner[:active_record, db: ApplicationRecord].strategy = :truncation
    DatabaseCleaner[:active_record, db: MysqlRecord].strategy = :truncation
    DatabaseCleaner[:active_record, db: SqliteRecord].strategy = :truncation

    DatabaseCleaner.start
  end

  teardown do
    DatabaseCleaner.clean
  end

  def exceed_query_limit(num, &)
    counter = QueryCounter.new
    ActiveSupport::Notifications.subscribed(counter.to_proc, 'sql.active_record', &)
    assert counter.query_count <= num, "Expected to run maximum #{num} queries, but ran #{counter.query_count}"
  end

  class QueryCounter
    attr_reader :query_count

    def initialize
      @query_count = 0
    end

    def to_proc
      method(:callback)
    end

    def callback(_name, _start, _finish, _message_id, values)
      @query_count += 1 unless %w[CACHE SCHEMA].include?(values[:name])
    end
  end
end

# Helper methods available globally
def env_db(connection = ActiveRecord::Base.connection)
  connection.adapter_name.downcase.to_sym
end

def sqlite?(connection = ActiveRecord::Base.connection)
  env_db(connection) == :sqlite3
end

def postgresql?(connection = ActiveRecord::Base.connection)
  env_db(connection) == :postgresql
end

def mysql?(connection = ActiveRecord::Base.connection)
  %i[mysql2 trilogy].include?(env_db(connection))
end

# Load support files
require_relative 'support/query_counter'

# Include QueryCounter in Minitest
Minitest::Test.include QueryCounter

puts "Testing ActiveRecord #{ActiveRecord.gem_version} and Ruby #{RUBY_VERSION}"
puts "Connection Pool size: #{ActiveRecord::Base.connection_pool.size}"

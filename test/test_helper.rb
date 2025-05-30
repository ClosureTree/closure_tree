# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
require_relative 'dummy/config/environment'
require 'rails/test_help'

require 'minitest/autorun'
require 'database_cleaner'
require 'support/query_counter'
require 'parallel'
require 'timecop'

# Configure parallel tests
Thread.abort_on_exception = true

# Configure advisory_lock
ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

# JRuby has issues with Timecop and ActiveRecord datetime casting
if defined?(JRUBY_VERSION)
  puts "Warning: Timecop tests may fail on JRuby due to Time class incompatibilities"
end

class ActiveSupport::TestCase
  # Configure DatabaseCleaner
  self.use_transactional_tests = false
  
  setup do
    DatabaseCleaner.strategy = :truncation
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
  
  # Helper method to skip tests on JRuby
  def skip_on_jruby(message = "Skipping on JRuby")
    skip message if defined?(JRUBY_VERSION)
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

# Helper methods available globally
def env_db
  @env_db ||= ActiveRecord::Base.connection.adapter_name.downcase.to_sym
end

def sqlite?
  env_db == :sqlite3
end

# Load support files
require_relative 'support/query_counter'

# Include QueryCounter in Minitest
Minitest::Test.send(:include, QueryCounter)

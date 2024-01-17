# frozen_string_literal: true

require 'active_record'
require 'minitest'
require 'minitest/autorun'
require 'database_cleaner'
require 'support/query_counter'
require 'parallel'

database_file = SecureRandom.hex
ActiveRecord::Base.configurations = debug = {
  default_env: {
    url: ENV['DATABASE_URL'].presence || "sqlite3://#{Dir.tmpdir}/#{database_file}.sqlite3",
    properties: { allowPublicKeyRetrieval: true } # for JRuby madness
  },
  secondary_env: {
    url: ENV['SECONDARY_DATABASE_URL'].presence || "sqlite3://#{Dir.tmpdir}/#{database_file}-s.sqlite3",
    properties: { allowPublicKeyRetrieval: true } # for JRuby madness
  }
}

puts "Testing with #{debug}"

ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex


def env_db
  @env_db ||= ActiveRecord::Base.connection_db_config.adapter.to_sym
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s
ActiveRecord::Base.establish_connection

# Use in specs to skip some tests
def sqlite?
  env_db == :sqlite3
end

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

# Configure parallel tests
Thread.abort_on_exception = true

require 'closure_tree'
require_relative '../spec/support/schema'
require_relative '../spec/support/models'
ActiveRecord::Base.connection.recreate_database('closure_tree_test') unless sqlite?

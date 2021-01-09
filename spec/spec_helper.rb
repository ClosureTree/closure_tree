# frozen_string_literal: true

require 'database_cleaner'
require 'closure_tree/test/matcher'
require 'tmpdir'
require 'timecop'
require 'forwardable'
require 'parallel'

begin
  require 'foreigner'
rescue LoadError
  #Foreigner is not needed in ActiveRecord 4.2+
end

require 'active_record'

Thread.abort_on_exception = true

def sqlite?
  ENV.fetch('DB_ADAPTER', 'sqlite3') == 'sqlite3'
end

# Configure RSpec
RSpec.configure do |config|
  config.include ClosureTree::Test::Matcher

  config.color = true
  config.fail_fast = false

  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  DatabaseCleaner.strategy = :truncation

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  if sqlite?
    config.before(:suite) do
      ENV['FLOCK_DIR'] = Dir.mktmpdir
    end

    config.after(:suite) do
      FileUtils.remove_entry_secure ENV['FLOCK_DIR']
    end
  end
end

# Configure ActiveRecord
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s

adapter = ENV.fetch('DB_ADAPTER', 'sqlite3')

config = {
  adapter:           adapter,
  database:          'closure_tree',
  encoding:          'utf8',
  pool:              50,
  timeout:           5000,
  reaping_frequency: 1000,
  min_messages:      'ERROR',
}

config =
  case adapter
  when 'postgresql'
    config.merge(host: '127.0.0.1', port: 5432, username: 'postgres', password: 'postgres')
  when 'mysql2'
    config.merge(host: '127.0.0.1', port: 3306, username: 'root', password: 'root')
  when 'sqlite3'
    config.merge(database: ':memory:')
  end

case adapter
when 'postgresql'
  # We need to switch on 'postgres' DB to destroy 'closure_tree' DB
  ActiveRecord::Base.establish_connection(config.merge(database: 'postgres', schema_search_path: 'public'))
  ActiveRecord::Base.connection.recreate_database(config[:database], config)

when 'mysql2'
  ActiveRecord::Base.establish_connection(config)
  ActiveRecord::Base.connection.recreate_database(config[:database], { charset: 'utf8', collation: 'utf8_unicode_ci' })
end

ActiveRecord::Base.establish_connection(config)
Foreigner.load if defined?(Foreigner)

# Require our gem
require 'closure_tree'

# Load test helpers
require_relative 'support/schema'
require_relative 'support/models'
require_relative 'support/tag_examples'
require_relative 'support/helpers'
require_relative 'support/exceed_query_limit'
require_relative 'support/query_counter'

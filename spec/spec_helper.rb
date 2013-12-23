$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)

require 'rubygems'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
require 'rspec'
require 'rails'
require 'active_record'
require 'foreigner'
require 'database_cleaner'
require 'active_record/fixtures'
require 'rspec/rails/adapters'
require 'rspec/rails/fixture_support'
require 'closure_tree'
require 'tmpdir'

if ENV['STDOUT_LOGGING']
  log = Logger.new(STDOUT)
  log.sev_threshold = Logger::DEBUG
  ActiveRecord::Base.logger = log
end

require 'yaml'
require 'erb'
ENV["DB"] ||= "mysql"
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s

if ENV['ATTR_ACCESSIBLE'] == '1'
  # turn on whitelisted attributes:
  ActiveRecord::Base.send(:include, ActiveModel::MassAssignmentSecurity)
end

ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(plugin_test_dir + "/db/database.yml")).result)

def recreate_db
  db_name = ActiveRecord::Base.configurations[ENV["DB"]]["database"]
  case ENV['DB'] || 'mysql'
    when 'sqlite'
      File.delete 'spec/sqlite3.db' if File.exist? 'spec/sqlite3.db'
    when 'postgresql'
      `psql -c 'DROP DATABASE #{db_name}' -U postgres`
      `psql -c 'CREATE DATABASE #{db_name}' -U postgres`
    when 'mysql'
      `mysql -e 'DROP DATABASE IF EXISTS #{db_name}'`
      `mysql -e 'CREATE DATABASE #{db_name}'`
  end
  ActiveRecord::Base.connection.reconnect!
end

ActiveRecord::Base.establish_connection(ENV["DB"])

ActiveRecord::Migration.verbose = false
if ENV['NONUKES']
  puts 'skipping database creation'
else
  Foreigner.load
  recreate_db
  require 'db/schema'
end
require 'support/models'

class Hash
  def render_from_yield(&block)
    inject({}) do |h, entry|
      k, v = entry
      h[block.call(k)] = if v.is_a?(Hash) then
        v.render_from_yield(&block)
      else
        block.call(v)
      end
      h
    end
  end
end

DB_QUERIES = []

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  def log_with_query_append(query, *args, &block)
    DB_QUERIES << query
    log_without_query_append(query, *args, &block)
  end

  alias_method_chain :log, :query_append
end

Thread.abort_on_exception = true

DatabaseCleaner.strategy = :truncation

RSpec.configure do |config|
  config.fixture_path = "#{plugin_test_dir}/fixtures"
  # disable rspec-rails' transaction wrapping:
  config.use_transactional_fixtures = false
  config.before(:each) do
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
    DB_QUERIES.clear
  end
  config.before(:all) do
    ENV['FLOCK_DIR'] = Dir.mktmpdir
  end
  config.after(:all) do
    FileUtils.remove_entry_secure ENV['FLOCK_DIR']
  end
end

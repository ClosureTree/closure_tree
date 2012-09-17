$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)

require 'rubygems'
require 'bundler/setup'

require 'rspec'
require 'logger'

require 'active_support'
require 'active_model'
require 'active_record'
require 'action_controller' # rspec-rails needs this :(

require 'closure_tree'

#log = Logger.new(STDOUT)
#log.sev_threshold = Logger::DEBUG
#ActiveRecord::Base.logger = log

require 'yaml'
require 'erb'
ENV["DB"] ||= "sqlite3mem"
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(plugin_test_dir + "/db/database.yml")).result)
ActiveRecord::Base.establish_connection(ENV["DB"])
ActiveRecord::Migration.verbose = false
require 'db/schema'
require 'support/models'
require 'rspec/rails' # TODO: clean this up-- I don't want to pull the elephant through the mouse hole just for fixture support

RSpec.configure do |config|
  config.fixture_path = "#{plugin_test_dir}/fixtures"
  # true runs the tests 1 second faster, but then you can't
  # see what's going on while debuggering with different db connections.
  config.use_transactional_fixtures = false
end

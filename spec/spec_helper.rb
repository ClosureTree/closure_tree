$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)

require 'rubygems'
require 'bundler/setup'

require 'rspec'
require 'logger'

require 'active_support'
require 'active_model'
require 'active_record'
require 'action_controller'

require 'closure_tree'

ActiveRecord::Base.logger = Logger.new(plugin_test_dir + "/debug.log")

require 'yaml'
require 'erb'
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(plugin_test_dir + "/db/database.yml")).result)
ActiveRecord::Base.establish_connection(ENV["DB"] || "mysql")
ActiveRecord::Migration.verbose = false
load(File.join(plugin_test_dir, "db", "schema.rb"))

require 'support/models'

require 'rspec/rails'
RSpec.configure do |config|
  config.fixture_path = "#{plugin_test_dir}/fixtures"
  # true runs the tests 1 second faster, but then you can't
  # see what's going on while debuggering with different db connections.
  config.use_transactional_fixtures = false
end

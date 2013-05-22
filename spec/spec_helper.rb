$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)

# Don't run the test for activerecord 4 if we're using ruby 1.8.7:
ruby_major_version, ruby_minor_version = RUBY_VERSION.split('.')[0..1]
if ENV['BUNDLE_GEMFILE'] =~ /rails-4/ &&
  ruby_major_version == "1" &&
  ruby_minor_version == "8"
  fail "Rails 4.0.x requires ruby >= 1.9.4"
end

require 'rubygems'
require 'bundler/setup'

require 'rspec'
require 'logger'

require 'rails/all'
require 'rspec/rails' # TODO: clean this up-- I don't want to pull the elephant through the mouse hole just for fixture support
require 'closure_tree'
require 'tmpdir'

#log = Logger.new(STDOUT)
#log.sev_threshold = Logger::DEBUG
#ActiveRecord::Base.logger = log

require 'yaml'
require 'erb'
ENV["DB"] ||= "mysql"
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(plugin_test_dir + "/db/database.yml")).result)
ActiveRecord::Base.establish_connection(ENV["DB"])
ActiveRecord::Migration.verbose = false
require 'db/schema'
require 'support/models'

DB_QUERIES = []

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  def log_with_query_append(query, *args, &block)
    DB_QUERIES << query
    log_without_query_append(query, *args, &block)
  end

  alias_method_chain :log, :query_append
end

Thread.abort_on_exception = true

RSpec.configure do |config|
  config.fixture_path = "#{plugin_test_dir}/fixtures"
  # true runs the tests 1 second faster, but then you can't
  # see what's going on while debuggering with different db connections.
  config.use_transactional_fixtures = false
  config.after(:each) do
    DB_QUERIES.clear
  end
  config.before(:all) do
    ENV['FLOCK_DIR'] = Dir.mktmpdir
  end
  config.after(:all) do
    FileUtils.remove_entry_secure ENV['FLOCK_DIR']
  end
end

database_folder = "#{File.dirname(__FILE__)}/../db"
database_adapter = ENV['DB'] ||= 'mysql'

def sqlite?
  ENV['DB'] == 'sqlite'
end

log = Logger.new('db.log')
log.sev_threshold = Logger::DEBUG
ActiveRecord::Base.logger = log

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s

def db_name
  @db_name ||= "closure_tree_test_#{rand(1..2**31)}"
end

ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read("#{database_folder}/database.yml")).result)

config = ActiveRecord::Base.configurations[database_adapter]

begin
  case database_adapter
  when 'sqlite'
    ActiveRecord::Base.establish_connection(database_adapter.to_sym)
  when 'mysql'
    ActiveRecord::Base.establish_connection(config.merge('database' => nil))
    ActiveRecord::Base.connection.recreate_database(config['database'], {charset: 'utf8', collation: 'utf8_unicode_ci'})
  when 'postgresql'
    ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
    ActiveRecord::Base.connection.recreate_database(config['database'], config.merge('encoding' => 'utf8'))
  end
end unless ENV['NONUKES']

ActiveRecord::Base.establish_connection(config)
Foreigner.load

require "#{database_folder}/schema"
require "#{database_folder}/models"

# See http://stackoverflow.com/a/22388177/1268016
def count_queries(&block)
  count = 0
  counter_fn = ->(name, started, finished, unique_id, payload) do
    count += 1 unless payload[:name].in? %w[CACHE SCHEMA]
  end
  ActiveSupport::Notifications.subscribed(counter_fn, 'sql.active_record', &block)
  count
end

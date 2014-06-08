database_folder = "#{File.dirname(__FILE__)}/../db"
database_adapter = ENV['DB'] ||= 'mysql'


if ENV['STDOUT_LOGGING']
  log = Logger.new(STDOUT)
  log.sev_threshold = Logger::DEBUG
  ActiveRecord::Base.logger = log
end


ActiveRecord::Migration.verbose = false
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read("#{database_folder}/database.yml")).result)

config = ActiveRecord::Base.configurations[database_adapter]

unless config['database'] == ':memory:'
  # Postgresql or Mysql
  config['database'].concat ENV['TRAVIS_JOB_NUMBER'].to_s.gsub(/\W/, '_')
end

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

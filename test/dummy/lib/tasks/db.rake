# frozen_string_literal: true

namespace :db do
  desc 'Setup all databases'
  task :setup_all do
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
      ActiveRecord::Base.establish_connection(db_config)
      ActiveRecord::Tasks::DatabaseTasks.create_current
      ActiveRecord::Tasks::DatabaseTasks.load_schema_current
    end
  end

  desc 'Drop all databases'
  task :drop_all do
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
      ActiveRecord::Base.establish_connection(db_config)
      ActiveRecord::Tasks::DatabaseTasks.drop_current
    end
  end

  desc 'Reset all databases'
  task reset_all: %i[drop_all setup_all]
end

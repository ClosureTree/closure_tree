# frozen_string_literal: true

namespace :db do
  desc 'Setup all databases'
  task setup_all: :environment do
    # Load primary database schema
    ActiveRecord::Base.establish_connection(:primary)
    ActiveRecord::Base.connection.disconnect! if ActiveRecord::Base.connection.active?
    ActiveRecord::Base.establish_connection(:primary)
    load Rails.root.join('db/schema.rb')

    # Load secondary (MySQL) database schema if configured
    if ENV['DATABASE_URL_MYSQL'].present?
      ActiveRecord::Base.establish_connection(:secondary)
      ActiveRecord::Base.connection.disconnect! if ActiveRecord::Base.connection.active?
      ActiveRecord::Base.establish_connection(:secondary)
      load Rails.root.join('db/secondary_schema.rb')
    end

    # SQLite is in-memory so it will be created automatically
    ActiveRecord::Base.establish_connection(:primary)
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

require 'erb'
require 'active_record'
require 'with_advisory_lock'
require 'tmpdir'
require 'securerandom'
require 'minitest'
require 'minitest/autorun'

ActiveRecord::Base.configurations = {
  default_env: {
    url: ENV.fetch('DATABASE_URL', "sqlite3://#{Dir.tmpdir}/#{SecureRandom.hex}.sqlite3"),
    properties: { allowPublicKeyRetrieval: true } # for JRuby madness
  }
}

ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

ActiveRecord::Base.establish_connection

def env_db
  @env_db ||= if ActiveRecord::Base.respond_to?(:connection_db_config)
                ActiveRecord::Base.connection_db_config.adapter
              else
                ActiveRecord::Base.connection_config[:adapter]
              end.to_sym
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.table_name_prefix = ENV['DB_PREFIX'].to_s
ActiveRecord::Base.table_name_suffix = ENV['DB_SUFFIX'].to_s
ActiveRecord::Base.establish_connection

def env_db
  @env_db ||= if ActiveRecord::Base.respond_to?(:connection_db_config)
                ActiveRecord::Base.connection_db_config.adapter
              else
                ActiveRecord::Base.connection_config[:adapter]
              end.to_sym
end

# Use in specs to skip some tests
def sqlite?
  env_db == :sqlite3
end

ENV['WITH_ADVISORY_LOCK_PREFIX'] ||= SecureRandom.hex

ActiveRecord::Base.connection.recreate_database("closure_tree_test") unless sqlite?
puts "Testing with #{env_db} database, ActiveRecord #{ActiveRecord.gem_version} and #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION} as #{RUBY_VERSION}"

require 'closure_tree'
require_relative '../spec/support/schema'
require_relative '../spec/support/models'
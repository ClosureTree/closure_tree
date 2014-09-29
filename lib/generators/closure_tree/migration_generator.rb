require 'rails/generators/named_base'
require 'rails/generators/active_record/migration'
require 'forwardable'

module ClosureTree
  module Generators # :nodoc:
    class MigrationGenerator < ::Rails::Generators::NamedBase # :nodoc:
      include ActiveRecord::Generators::Migration

      extend Forwardable
      def_delegators :ct, :hierarchy_table_name, :primary_key_type

      def self.default_generator_root
        File.dirname(__FILE__)
      end

      def create_migration_file
        migration_template 'create_hierarchies_table.rb.erb', "db/migrate/create_#{singular_table_name}_hierarchies.rb"
      end

      def migration_class_name
        "Create#{ct.hierarchy_class_name}".gsub(/\W/, '')
      end

      def ct
        @ct ||= class_name.constantize._ct
      end
    end
  end
end

require 'rails/generators/named_base'
require 'rails/generators/active_record/migration'

module ClosureTree
  module Generators # :nodoc:
    class MigrationGenerator < ::Rails::Generators::NamedBase # :nodoc:
      include ActiveRecord::Generators::Migration

      def self.default_generator_root
        File.dirname(__FILE__)
      end

      def create_migration_file
        migration_template 'create_hierarchies_table.rb.erb', "db/migrate/create_#{singular_table_name}_hierarchies.rb"
      end

      private

      def migration_class_name
        "Create#{class_name}Hierarchies".gsub('::', '')
      end

      def model_name
        file_name
      end

      def hierarchies_table
        ":#{klass.table_name.singularize}"
      end

      def klass
        class_name.constantize
      end

      def primary_key_type
        klass.columns.first.sql_type
      end

    end
  end
end

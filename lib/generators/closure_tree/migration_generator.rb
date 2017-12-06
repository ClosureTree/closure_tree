require 'closure_tree/active_record_support'
require 'forwardable'
require 'rails/generators'
require 'rails/generators/active_record'
require 'rails/generators/named_base'

module ClosureTree
  module Generators # :nodoc:
    class MigrationGenerator < Rails::Generators::NamedBase # :nodoc:
      include Rails::Generators::Migration
      include ClosureTree::ActiveRecordSupport
      extend Forwardable
      def_delegators :ct, :hierarchy_table_name, :primary_key_type

      def self.default_generator_root
        File.dirname(__FILE__)
      end

      def create_migration_file
        migration_template 'create_hierarchies_table.rb.erb', "db/migrate/create_#{migration_name}.rb"
      end

      private

      def migration_name
        remove_prefix_and_suffix(ct.hierarchy_table_name)
      end

      def migration_class_name
        "Create#{migration_name.camelize}"
      end

      def target_class
        @target_class ||= class_name.constantize
      end

      def ct
        @ct ||= if target_class.respond_to?(:_ct)
          target_class._ct
        else
          fail "Please RTFM and add the `has_closure_tree` (or `acts_as_tree`) annotation to #{class_name} before creating the migration."
        end
      end

      def migration_version
        major = ActiveRecord::VERSION::MAJOR
        if major >= 5
          "[#{major}.#{ActiveRecord::VERSION::MINOR}]"
        end
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end
  end
end

# frozen_string_literal: true

require 'test_helper'
require 'generators/closure_tree/migration_generator'

module ClosureTree
  module Generators
    class MigrationGeneratorTest < Rails::Generators::TestCase
      tests MigrationGenerator
      destination File.expand_path('../tmp', __dir__)
      setup :prepare_destination

      def test_generator_output
        run_generator %w[tag]
        migration_file = migration_file_name('db/migrate/create_tag_hierarchies.rb')
        content = File.read(migration_file)
        assert_match(/t.integer :ancestor_id, null: false/, content)
        assert_match(/t.integer :descendant_id, null: false/, content)
        assert_match(/t.integer :generations, null: false/, content)
        assert_match(/add_index :tag_hierarchies/, content)
      end

      def test_generator_output_with_namespaced_model
        run_generator %w[Namespace::Type]
        migration_file = migration_file_name('db/migrate/create_namespace_type_hierarchies.rb')
        content = File.read(migration_file)
        assert_match(/t.integer :ancestor_id, null: false/, content)
        assert_match(/t.integer :descendant_id, null: false/, content)
        assert_match(/t.integer :generations, null: false/, content)
        assert_match(/add_index :namespace_type_hierarchies/, content)
      end

      def test_generator_output_with_namespaced_model_with_slash
        run_generator %w[namespace/type]
        migration_file = migration_file_name('db/migrate/create_namespace_type_hierarchies.rb')
        content = File.read(migration_file)
        assert_match(/t.integer :ancestor_id, null: false/, content)
        assert_match(/t.integer :descendant_id, null: false/, content)
        assert_match(/t.integer :generations, null: false/, content)
        assert_match(/add_index :namespace_type_hierarchies/, content)
      end

      def test_should_run_all_tasks_in_generator_without_errors
        gen = generator %w[tag]
        capture_io { gen.invoke_all }
      end
    end
  end
end

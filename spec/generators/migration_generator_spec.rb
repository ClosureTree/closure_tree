require 'spec_helper'
require "generator_spec/test_case"

# Generators are not automatically loaded by Rails
require 'generators/closure_tree/migration_generator'

RSpec.describe ClosureTree::Generators::MigrationGenerator, type: :generator do
  include GeneratorSpec::TestCase

  # Tell generator where to put its output
  destination Dir.mktmpdir
  before { prepare_destination }

  describe 'generator output' do
    before { run_generator %w(tag) }
    subject { File.read migration_file_name('db/migrate/create_tag_hierarchies.rb') }
    it { is_expected.to match(/t.integer :ancestor_id, null: false/) }
    it { is_expected.to match(/t.integer :descendant_id, null: false/) }
    it { is_expected.to match(/t.integer :generations, null: false/) }
    it { is_expected.to match(/add_index :tag_hierarchies/) }
  end

  describe 'generator output with namespaced model' do
    before { run_generator %w(Namespace::Type) }
    subject { File.read migration_file_name('db/migrate/create_namespace_type_hierarchies.rb') }
    it { is_expected.to match(/t.integer :ancestor_id, null: false/) }
    it { is_expected.to match(/t.integer :descendant_id, null: false/) }
    it { is_expected.to match(/t.integer :generations, null: false/) }
    it { is_expected.to match(/add_index :namespace_type_hierarchies/) }
  end

  describe 'generator output with namespaced model with /' do
    before { run_generator %w(namespace/type) }
    subject { File.read migration_file_name('db/migrate/create_namespace_type_hierarchies.rb') }
    it { is_expected.to match(/t.integer :ancestor_id, null: false/) }
    it { is_expected.to match(/t.integer :descendant_id, null: false/) }
    it { is_expected.to match(/t.integer :generations, null: false/) }
    it { is_expected.to match(/add_index :namespace_type_hierarchies/) }
  end

  it 'should run all tasks in generator without errors' do
    gen = generator %w(tag)
    expect(gen).to receive :create_migration_file
    capture(:stdout) { gen.invoke_all }
  end
end

require 'spec_helper'
require 'ammeter/init'

# Generators are not automatically loaded by Rails
require 'generators/closure_tree/migration_generator'

RSpec.describe ClosureTree::Generators::MigrationGenerator, type: :generator do
  TMPDIR = Dir.mktmpdir
  # Tell generator where to put its output
  destination TMPDIR
  before { prepare_destination }

  describe 'generator output' do
    before { run_generator %w(tag) }
    subject { migration_file('db/migrate/create_tag_hierarchies.rb') }
    it { is_expected.to be_a_migration }
    it { is_expected.to contain(/t.integer :ancestor_id, null: false/) }
    it { is_expected.to contain(/t.integer :descendant_id, null: false/) }
    it { is_expected.to contain(/t.integer :generations, null: false/) }
    it { is_expected.to contain(/add_index :tag_hierarchies/) }
  end

  describe 'generator output with namespaced model' do
    before { run_generator %w(Namespace::Type) }
    subject { migration_file('db/migrate/create_namespace_type_hierarchies.rb') }
    it { is_expected.to be_a_migration }
    it { is_expected.to contain(/t.integer :ancestor_id, null: false/) }
    it { is_expected.to contain(/t.integer :descendant_id, null: false/) }
    it { is_expected.to contain(/t.integer :generations, null: false/) }
    it { is_expected.to contain(/add_index :namespace_type_hierarchies/) }
  end

  describe 'generator output with namespaced model with /' do
    before { run_generator %w(namespace/type) }
    subject { migration_file('db/migrate/create_namespace_type_hierarchies.rb') }
    it { is_expected.to be_a_migration }
    it { is_expected.to contain(/t.integer :ancestor_id, null: false/) }
    it { is_expected.to contain(/t.integer :descendant_id, null: false/) }
    it { is_expected.to contain(/t.integer :generations, null: false/) }
    it { is_expected.to contain(/add_index :namespace_type_hierarchies/) }
  end

  it 'should run all tasks in generator without errors' do
    gen = generator %w(tag)
    expect(gen).to receive :create_migration_file
    capture(:stdout) { gen.invoke_all }
  end
end

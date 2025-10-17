# frozen_string_literal: true

require 'test_helper'

describe SchemaType do
  before do
    skip 'PostgreSQL only' unless postgresql?
  end

  def assert_lineage(parent, child)
    assert_equal parent, child.parent
    assert_equal [child, parent], child.self_and_ancestors

    # make sure reloading doesn't affect the self_and_ancestors:
    child.reload
    assert_equal [child, parent], child.self_and_ancestors
  end

  it 'properly handles schema-qualified table names' do
    assert_equal 'test_schema.schema_types', SchemaType.table_name
    assert_equal 'test_schema.schema_type_hierarchies', SchemaTypeHierarchy.table_name
  end

  it 'finds self and parents when children << is used' do
    parent = SchemaType.new(name: 'Electronics')
    child = SchemaType.new(name: 'Phones')
    parent.children << child
    parent.save
    assert_lineage(parent, child)
  end

  it 'finds self and parents properly if the constructor is used' do
    parent = SchemaType.create(name: 'Electronics')
    child = SchemaType.create(name: 'Phones', parent: parent)
    assert_lineage(parent, child)
  end

  it 'creates hierarchy records in the schema-qualified table' do
    parent = SchemaType.create!(name: 'Electronics')
    child = SchemaType.create!(name: 'Phones', parent: parent)

    hierarchy = SchemaTypeHierarchy.where(ancestor_id: parent.id, descendant_id: child.id).first
    refute_nil hierarchy
    assert_equal 1, hierarchy.generations
  end

  it 'fixes self_and_ancestors properly on reparenting' do
    a = SchemaType.create! name: 'Electronics'
    b = SchemaType.create! name: 'Phones'
    assert_equal([b], b.self_and_ancestors.to_a)
    a.children << b
    assert_equal([b, a], b.self_and_ancestors.to_a)
  end

  it 'supports tree operations with schema-qualified tables' do
    root = SchemaType.create!(name: 'Electronics')
    child1 = SchemaType.create!(name: 'Computers', parent: root)
    child2 = SchemaType.create!(name: 'Phones', parent: root)
    grandchild = SchemaType.create!(name: 'Laptops', parent: child1)

    assert_equal 2, root.children.count
    assert_equal 1, child1.children.count
    assert_equal 0, child2.children.count
    assert_equal [grandchild, child1, root], grandchild.self_and_ancestors
    assert_equal [root, child1, child2, grandchild], root.self_and_descendants.order(:name)
  end
end

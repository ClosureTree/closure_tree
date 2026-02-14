# frozen_string_literal: true

require 'test_helper'

class OrderValueCrossDatabaseTest < ActiveSupport::TestCase
  # Setup for SQLite memory tables
  def setup
    super
    # Create memory tables for SQLite with sort_order column
    LiteRecord.connection.create_table :memory_tags, force: true do |t|
      t.string :name
      t.integer :parent_id
      t.integer :sort_order
      t.timestamps
    end

    LiteRecord.connection.create_table :memory_tag_hierarchies, id: false, force: true do |t|
      t.integer :ancestor_id, null: false
      t.integer :descendant_id, null: false
      t.integer :generations, null: false
    end

    LiteRecord.connection.add_index :memory_tag_hierarchies, %i[ancestor_id descendant_id generations],
                                    unique: true, name: 'memory_tag_anc_desc_idx'
    LiteRecord.connection.add_index :memory_tag_hierarchies, [:descendant_id], name: 'memory_tag_desc_idx'

    # Clean up existing data
    Label.delete_all
    LabelHierarchy.delete_all
    SecondaryTag.delete_all
    SecondaryTagHierarchy.delete_all
  end

  def teardown
    LiteRecord.connection.drop_table :memory_tag_hierarchies, if_exists: true
    LiteRecord.connection.drop_table :memory_tags, if_exists: true
    super
  end

  # ===========================================
  # PostgreSQL (Label) Tests
  # ===========================================

  test 'PostgreSQL: should reorder remaining root nodes when a root node becomes a child via prepend_child' do
    node_1 = Label.create(name: 'node_1')
    node_2 = Label.create(name: 'node_2')
    node_3 = Label.create(name: 'node_3')
    node_4 = Label.create(name: 'node_4')

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value

    node_3.prepend_child(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id
    assert_equal 0, node_2.order_value

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  test 'PostgreSQL: should reorder remaining root nodes when a root node becomes a child via append_child' do
    node_1 = Label.create(name: 'node_1')
    node_2 = Label.create(name: 'node_2')
    node_3 = Label.create(name: 'node_3')
    node_4 = Label.create(name: 'node_4')

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value

    node_3.append_child(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id
    assert_equal 0, node_2.order_value

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  test 'PostgreSQL: should reorder remaining root nodes when a root node becomes a child via add_sibling' do
    node_1 = Label.create(name: 'node_1')
    node_2 = Label.create(name: 'node_2')
    node_3 = Label.create(name: 'node_3')
    node_4 = Label.create(name: 'node_4')

    child = Label.create(name: 'child', parent: node_3)

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value
    assert_equal 0, child.order_value

    child.add_sibling(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  # ===========================================
  # SQLite (MemoryTag) Tests
  # ===========================================

  test 'SQLite: should reorder remaining root nodes when a root node becomes a child via prepend_child' do
    node_1 = MemoryTag.create(name: 'node_1')
    node_2 = MemoryTag.create(name: 'node_2')
    node_3 = MemoryTag.create(name: 'node_3')
    node_4 = MemoryTag.create(name: 'node_4')

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value

    node_3.prepend_child(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id
    assert_equal 0, node_2.order_value

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  test 'SQLite: should reorder remaining root nodes when a root node becomes a child via append_child' do
    node_1 = MemoryTag.create(name: 'node_1')
    node_2 = MemoryTag.create(name: 'node_2')
    node_3 = MemoryTag.create(name: 'node_3')
    node_4 = MemoryTag.create(name: 'node_4')

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value

    node_3.append_child(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id
    assert_equal 0, node_2.order_value

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  test 'SQLite: should reorder remaining root nodes when a root node becomes a child via add_sibling' do
    node_1 = MemoryTag.create(name: 'node_1')
    node_2 = MemoryTag.create(name: 'node_2')
    node_3 = MemoryTag.create(name: 'node_3')
    node_4 = MemoryTag.create(name: 'node_4')

    child = MemoryTag.create(name: 'child', parent: node_3)

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value
    assert_equal 0, child.order_value

    child.add_sibling(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  # ===========================================
  # MySQL (SecondaryTag) Tests
  # ===========================================

  test 'MySQL: should reorder remaining root nodes when a root node becomes a child via prepend_child' do
    skip 'MySQL not configured' unless mysql?(SecondaryRecord.connection)

    node_1 = SecondaryTag.create(name: 'node_1')
    node_2 = SecondaryTag.create(name: 'node_2')
    node_3 = SecondaryTag.create(name: 'node_3')
    node_4 = SecondaryTag.create(name: 'node_4')

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value

    node_3.prepend_child(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id
    assert_equal 0, node_2.order_value

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  test 'MySQL: should reorder remaining root nodes when a root node becomes a child via append_child' do
    skip 'MySQL not configured' unless mysql?(SecondaryRecord.connection)

    node_1 = SecondaryTag.create(name: 'node_1')
    node_2 = SecondaryTag.create(name: 'node_2')
    node_3 = SecondaryTag.create(name: 'node_3')
    node_4 = SecondaryTag.create(name: 'node_4')

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value

    node_3.append_child(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id
    assert_equal 0, node_2.order_value

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  test 'MySQL: should reorder remaining root nodes when a root node becomes a child via add_sibling' do
    skip 'MySQL not configured' unless mysql?(SecondaryRecord.connection)

    node_1 = SecondaryTag.create(name: 'node_1')
    node_2 = SecondaryTag.create(name: 'node_2')
    node_3 = SecondaryTag.create(name: 'node_3')
    node_4 = SecondaryTag.create(name: 'node_4')

    child = SecondaryTag.create(name: 'child', parent: node_3)

    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value
    assert_equal 0, child.order_value

    child.add_sibling(node_2)

    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    assert_equal node_3.id, node_2._ct_parent_id

    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end
end

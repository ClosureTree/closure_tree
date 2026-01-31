# frozen_string_literal: true

require 'test_helper'

class LabelOrderValueTest < ActiveSupport::TestCase
  def setup
    Label.delete_all
    LabelHierarchy.delete_all
  end

  test 'should set order_value on roots for Label' do
    root = Label.create(name: 'root')
    assert_equal 0, root.order_value
  end

  test 'should set order_value with siblings for Label' do
    root = Label.create(name: 'root')
    a = root.children.create(name: 'a')
    b = root.children.create(name: 'b')
    c = root.children.create(name: 'c')

    assert_equal 0, a.order_value
    assert_equal 1, b.order_value
    assert_equal 2, c.order_value
  end

  test 'should reset order_value when a node is moved to another location for Label' do
    root = Label.create(name: 'root')
    a = root.children.create(name: 'a')
    b = root.children.create(name: 'b')
    c = root.children.create(name: 'c')

    root2 = Label.create(name: 'root2')
    root2.add_child b

    assert_equal 0, a.order_value
    assert_equal 0, b.order_value
    assert_equal 1, c.reload.order_value
  end

  test 'should set order_value on roots for LabelWithoutRootOrdering' do
    root = LabelWithoutRootOrdering.create(name: 'root')
    assert_nil root.order_value
  end

  test 'should set order_value with siblings for LabelWithoutRootOrdering' do
    root = LabelWithoutRootOrdering.create(name: 'root')
    a = root.children.create(name: 'a')
    b = root.children.create(name: 'b')
    c = root.children.create(name: 'c')

    assert_equal 0, a.order_value
    assert_equal 1, b.order_value
    assert_equal 2, c.order_value
  end

  test 'should reorder remaining root nodes when a root node becomes a child via prepend_child' do
    node_1 = Label.create(name: 'node_1')
    node_2 = Label.create(name: 'node_2')
    node_3 = Label.create(name: 'node_3')
    node_4 = Label.create(name: 'node_4')

    # Verify initial positions
    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value

    # Move node_2 as a child of node_3 using prepend_child
    node_3.prepend_child(node_2)

    # Reload all nodes to get updated positions
    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    # Verify node_2 is now a child of node_3 with position 0
    assert_equal node_3.id, node_2._ct_parent_id
    assert_equal 0, node_2.order_value

    # Verify remaining root nodes have sequential positions without gaps
    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end

  test 'should reorder remaining root nodes when a root node becomes a child via add_sibling' do
    node_1 = Label.create(name: 'node_1')
    node_2 = Label.create(name: 'node_2')
    node_3 = Label.create(name: 'node_3')
    node_4 = Label.create(name: 'node_4')

    # Create a child under node_3
    child = Label.create(name: 'child', parent: node_3)

    # Verify initial positions
    assert_equal 0, node_1.order_value
    assert_equal 1, node_2.order_value
    assert_equal 2, node_3.order_value
    assert_equal 3, node_4.order_value
    assert_equal 0, child.order_value

    # Move node_2 as a sibling of child (making it a child of node_3)
    child.add_sibling(node_2)

    # Reload all nodes to get updated positions
    node_1.reload
    node_2.reload
    node_3.reload
    node_4.reload

    # Verify node_2 is now a child of node_3
    assert_equal node_3.id, node_2._ct_parent_id

    # Verify remaining root nodes have sequential positions without gaps
    assert_equal 0, node_1.order_value
    assert_equal 1, node_3.order_value
    assert_equal 2, node_4.order_value
  end
end

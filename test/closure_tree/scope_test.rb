# frozen_string_literal: true

require 'test_helper'

class ScopeTest < ActiveSupport::TestCase
  def setup
    ScopedItem.delete_all
    ScopedItemHierarchy.delete_all
    MultiScopedItem.delete_all
  end

  def test_roots_with_single_scope
    root1 = ScopedItem.create!(name: 'root1', user_id: 1)
    root2 = ScopedItem.create!(name: 'root2', user_id: 1)
    root3 = ScopedItem.create!(name: 'root3', user_id: 2)

    scoped_roots = ScopedItem.roots.where(user_id: 1)
    assert_equal 2, scoped_roots.count
    assert_includes scoped_roots, root1
    assert_includes scoped_roots, root2
    refute_includes scoped_roots, root3
  end

  def test_roots_with_multiple_scope
    root1 = MultiScopedItem.create!(name: 'root1', user_id: 1, group_id: 10)
    root2 = MultiScopedItem.create!(name: 'root2', user_id: 1, group_id: 10)
    root3 = MultiScopedItem.create!(name: 'root3', user_id: 1, group_id: 20)
    root4 = MultiScopedItem.create!(name: 'root4', user_id: 2, group_id: 10)

    scoped_roots = MultiScopedItem.roots.where(user_id: 1, group_id: 10)
    assert_equal 2, scoped_roots.count
    assert_includes scoped_roots, root1
    assert_includes scoped_roots, root2
    refute_includes scoped_roots, root3
    refute_includes scoped_roots, root4
  end

  def test_siblings_with_scope
    parent = ScopedItem.create!(name: 'parent', user_id: 1)
    child1 = parent.children.create!(name: 'child1', user_id: 1)
    child2 = parent.children.create!(name: 'child2', user_id: 1)
    child3 = parent.children.create!(name: 'child3', user_id: 2)

    siblings = child1.siblings
    assert_equal 1, siblings.count
    assert_includes siblings, child2
    refute_includes siblings, child3
  end

  def test_siblings_with_multiple_scope
    parent = MultiScopedItem.create!(name: 'parent', user_id: 1, group_id: 10)
    child1 = parent.children.create!(name: 'child1', user_id: 1, group_id: 10)
    child2 = parent.children.create!(name: 'child2', user_id: 1, group_id: 10)
    child3 = parent.children.create!(name: 'child3', user_id: 1, group_id: 20)
    child4 = parent.children.create!(name: 'child4', user_id: 2, group_id: 10)

    siblings = child1.siblings
    assert_equal 1, siblings.count
    assert_includes siblings, child2
    refute_includes siblings, child3
    refute_includes siblings, child4
  end

  def test_reordering_siblings_with_scope
    parent = ScopedItem.create!(name: 'parent', user_id: 1)
    child1 = parent.children.create!(name: 'child1', user_id: 1)
    child2 = parent.children.create!(name: 'child2', user_id: 1)
    child3 = parent.children.create!(name: 'child3', user_id: 2)

    child1._ct_reorder_siblings

    child1.reload
    child2.reload
    child3.reload

    assert_equal 0, child1.order_value
    assert_equal 1, child2.order_value
    assert_equal 0, child3.order_value
  end

  def test_reordering_siblings_with_multiple_scope
    parent = MultiScopedItem.create!(name: 'parent', user_id: 1, group_id: 10)
    child1 = parent.children.create!(name: 'child1', user_id: 1, group_id: 10)
    child2 = parent.children.create!(name: 'child2', user_id: 1, group_id: 10)
    child3 = parent.children.create!(name: 'child3', user_id: 1, group_id: 20)
    child4 = parent.children.create!(name: 'child4', user_id: 2, group_id: 10)

    child1._ct_reorder_siblings

    child1.reload
    child2.reload
    child3.reload
    child4.reload

    assert_equal 0, child1.order_value
    assert_equal 1, child2.order_value
    assert_equal 0, child3.order_value
    assert_equal 0, child4.order_value
  end

  def test_reordering_children_with_scope
    parent1 = ScopedItem.create!(name: 'parent1', user_id: 1)
    parent2 = ScopedItem.create!(name: 'parent2', user_id: 2)

    child1 = parent1.children.create!(name: 'child1', user_id: 1)
    child2 = parent1.children.create!(name: 'child2', user_id: 1)
    child3 = parent1.children.create!(name: 'child3', user_id: 1)

    parent1._ct_reorder_children

    child1.reload
    child2.reload
    child3.reload

    assert_equal 0, child1.order_value
    assert_equal 1, child2.order_value
    assert_equal 2, child3.order_value
  end

  def test_reordering_children_with_multiple_scope
    parent1 = MultiScopedItem.create!(name: 'parent1', user_id: 1, group_id: 10)
    parent2 = MultiScopedItem.create!(name: 'parent2', user_id: 1, group_id: 20)

    child1 = parent1.children.create!(name: 'child1', user_id: 1, group_id: 10)
    child2 = parent1.children.create!(name: 'child2', user_id: 1, group_id: 10)
    child3 = parent1.children.create!(name: 'child3', user_id: 1, group_id: 20)
    child4 = parent1.children.create!(name: 'child4', user_id: 2, group_id: 10)

    parent1._ct_reorder_children

    child1.reload
    child2.reload
    child3.reload
    child4.reload

    assert_equal 0, child1.order_value
    assert_equal 1, child2.order_value
    assert_equal 0, child3.order_value
    assert_equal 0, child4.order_value
  end

  def test_reordering_children_excludes_different_scope
    parent1 = ScopedItem.create!(name: 'parent1', user_id: 1)

    child1 = parent1.children.create!(name: 'child1', user_id: 1)
    child2 = parent1.children.create!(name: 'child2', user_id: 1)
    child3 = parent1.children.create!(name: 'child3', user_id: 2)

    initial_order = child3.order_value

    parent1._ct_reorder_children

    child1.reload
    child2.reload
    child3.reload

    assert_equal 0, child1.order_value
    assert_equal 1, child2.order_value
    assert_equal initial_order, child3.order_value, 'child3 with different scope should not be reordered'
  end

  def test_scope_values_from_instance
    instance = ScopedItem.new(user_id: 123)
    scope_values = instance._ct.scope_values_from_instance(instance)
    assert_equal({ user_id: 123 }, scope_values)
  end

  def test_scope_values_from_instance_multiple_columns
    instance = MultiScopedItem.new(user_id: 123, group_id: 456)
    scope_values = instance._ct.scope_values_from_instance(instance)
    assert_equal({ user_id: 123, group_id: 456 }, scope_values)
  end

  def test_scope_columns_method
    assert_equal [:user_id], ScopedItem._ct.scope_columns
    assert_equal [:user_id, :group_id], MultiScopedItem._ct.scope_columns
  end

  def test_scope_values_from_instance_with_nil_value_symbol_scope
    instance = ScopedItem.new(user_id: nil)
    scope_values = instance._ct.scope_values_from_instance(instance)
    assert_equal({ user_id: nil }, scope_values)
  end

  def test_scope_values_from_instance_with_nil_value_array_scope
    instance = MultiScopedItem.new(user_id: nil, group_id: nil)
    scope_values = instance._ct.scope_values_from_instance(instance)
    assert_equal({ user_id: nil, group_id: nil }, scope_values)
  end

  def test_ordering_with_nil_scope_values_symbol_scope
    root1 = ScopedItem.create!(name: 'root1', user_id: nil)
    root2 = ScopedItem.create!(name: 'root2', user_id: 1)
    root3 = ScopedItem.create!(name: 'root3', user_id: nil)

    assert_equal 0, root1.order_value
    assert_equal 1, root3.order_value
    assert_equal 0, root2.order_value
  end

  def test_ordering_with_nil_scope_values_array_scope
    root1 = MultiScopedItem.create!(name: 'root1', user_id: nil, group_id: nil)
    root2 = MultiScopedItem.create!(name: 'root2', user_id: 1, group_id: 1)
    root3 = MultiScopedItem.create!(name: 'root3', user_id: nil, group_id: nil)

    assert_equal 0, root1.order_value
    assert_equal 1, root3.order_value
    assert_equal 0, root2.order_value
  end

  def test_build_scope_where_clause_with_nil_value_pg
    support = ScopedItem._ct
    scope_conditions = { user_id: nil, group_id: 789 }
    clause = support.build_scope_where_clause(scope_conditions)

    assert_includes clause, 'IS NULL'
    assert_includes clause, '789'
  end

  def test_build_scope_where_clause_with_nil_value_mysql
    support = SecondaryTag._ct
    scope_conditions = { user_id: nil, group_id: 123 }
    clause = support.build_scope_where_clause(scope_conditions)

    assert_includes clause, 'IS NULL'
    assert_includes clause, '123'
  end

  def test_build_scope_where_clause_with_nil_value_sqlite
    support = MemoryTag._ct
    scope_conditions = { user_id: nil, group_id: 456 }
    clause = support.build_scope_where_clause(scope_conditions)

    assert_includes clause, 'IS NULL'
    assert_includes clause, '456'
  end

  def test_reorder_previous_scope_siblings_when_scope_changes
    # Create items in scope user_id: 1
    item1 = ScopedItem.create!(name: 'item1', user_id: 1)
    item2 = ScopedItem.create!(name: 'item2', user_id: 1)
    item3 = ScopedItem.create!(name: 'item3', user_id: 1)

    # Verify initial order values
    assert_equal 0, item1.order_value
    assert_equal 1, item2.order_value
    assert_equal 2, item3.order_value

    # Move item2 to a different scope (user_id: 2)
    item2.update!(user_id: 2)

    # Reload all items
    item1.reload
    item2.reload
    item3.reload

    # item2 should be first in its new scope
    assert_equal 0, item2.order_value

    # item1 and item3 should be reordered without gaps in old scope
    assert_equal 0, item1.order_value
    assert_equal 1, item3.order_value
  end

  def test_reorder_previous_scope_siblings_when_multiple_scope_changes
    # Create items in scope user_id: 1, group_id: 10
    item1 = MultiScopedItem.create!(name: 'item1', user_id: 1, group_id: 10)
    item2 = MultiScopedItem.create!(name: 'item2', user_id: 1, group_id: 10)
    item3 = MultiScopedItem.create!(name: 'item3', user_id: 1, group_id: 10)

    # Verify initial order values
    assert_equal 0, item1.order_value
    assert_equal 1, item2.order_value
    assert_equal 2, item3.order_value

    # Move item2 to a different scope (user_id: 2, group_id: 10)
    item2.update!(user_id: 2)

    # Reload all items
    item1.reload
    item2.reload
    item3.reload

    # item2 should be first in its new scope
    assert_equal 0, item2.order_value

    # item1 and item3 should be reordered without gaps in old scope
    assert_equal 0, item1.order_value
    assert_equal 1, item3.order_value
  end

  def test_scope_changed_detection
    # Test scope_changed? by checking the actual reordering behavior
    # which implicitly tests that scope_changed? works during callbacks
    item1 = ScopedItem.create!(name: 'item1', user_id: 1)
    item2 = ScopedItem.create!(name: 'item2', user_id: 1)

    assert_equal 0, item1.order_value
    assert_equal 1, item2.order_value

    # Change scope - if scope_changed? works, item1 will be reordered in new scope
    item2.update!(user_id: 2)

    item1.reload
    item2.reload

    # item2 should be 0 in new scope (proves scope change was detected)
    assert_equal 0, item2.order_value
    # item1 should remain 0 (was already 0, reordering removes gap from item2)
    assert_equal 0, item1.order_value
  end

  def test_previous_scope_values_from_instance
    # Test previous_scope_values by checking that OLD scope siblings are reordered
    # which implicitly tests that previous scope values are correctly retrieved
    item1 = ScopedItem.create!(name: 'item1', user_id: 1)
    item2 = ScopedItem.create!(name: 'item2', user_id: 1)
    item3 = ScopedItem.create!(name: 'item3', user_id: 1)

    assert_equal 0, item1.order_value
    assert_equal 1, item2.order_value
    assert_equal 2, item3.order_value

    # Move middle item to different scope
    item2.update!(user_id: 2)

    item1.reload
    item3.reload

    # If previous_scope_values works, item3 should now be 1 (gap filled)
    assert_equal 0, item1.order_value
    assert_equal 1, item3.order_value
  end
end

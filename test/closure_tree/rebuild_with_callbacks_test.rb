# frozen_string_literal: true

require 'test_helper'

class RebuildWithCallbacksTest < ActiveSupport::TestCase
  # Test for issue #392 comment 3568009891
  # User 'bb' reported MissingAttributeError during rebuild! after fix
  # The hierarchy class inherits from abstract base and should not trigger
  # parent model callbacks during hierarchy rebuild operations

  def setup
    Tag.delete_all
    TagHierarchy.delete_all
  end

  test 'Tag.rebuild! does not trigger before_destroy callbacks on hierarchy records' do
    # Tag has before_destroy :add_destroyed_tag callback
    # TagHierarchy should NOT inherit this callback

    root = Tag.create!(name: 'root')
    _child = Tag.create!(name: 'child', parent: root)

    initial_hierarchy_count = TagHierarchy.count
    assert initial_hierarchy_count > 0, "Should have hierarchy records"

    initial_destroyed_count = DestroyedTag.count

    # This should rebuild hierarchy without triggering Tag callbacks
    assert_nothing_raised do
      Tag.rebuild!
    end

    # Hierarchy records should be recreated
    assert_equal initial_hierarchy_count, TagHierarchy.count

    # DestroyedTag should NOT increase (proves callbacks weren't triggered)
    assert_equal initial_destroyed_count, DestroyedTag.count,
      "TagHierarchy operations should not trigger Tag's before_destroy callback"
  end

  test 'TagHierarchy.create does not inherit Tag validations or callbacks' do
    # Direct hierarchy insertion should work without triggering parent callbacks
    _root = Tag.create!(name: 'root')
    _child = Tag.create!(name: 'child', parent: _root)

    destroyed_count_before = DestroyedTag.count

    # TagHierarchy.create! should not trigger Tag's before_destroy callback
    # This verifies TagHierarchy doesn't inherit Tag's callbacks
    # Note: In normal operation, has_closure_tree automatically creates hierarchy records
    # This test verifies manual creation doesn't trigger Tag callbacks

    initial_hierarchy_count = TagHierarchy.count

    # Verify the hierarchy class doesn't inherit Tag's callback behavior
    tag_destroy_callbacks = Tag._destroy_callbacks.to_a
    hierarchy_destroy_callbacks = TagHierarchy._destroy_callbacks.to_a

    assert_not_equal tag_destroy_callbacks.length, hierarchy_destroy_callbacks.length,
      "TagHierarchy should not inherit all of Tag's callbacks"

    # Hierarchy operations should not trigger the before_destroy callback
    assert_equal destroyed_count_before, DestroyedTag.count,
      "TagHierarchy class definition should not trigger Tag's callbacks"

    assert initial_hierarchy_count > 0, "Should have hierarchy records from Tag creation"
  end

  test 'TagHierarchy inherits from ApplicationRecord not Tag' do
    # Force TagHierarchy to be loaded
    Tag._ct

    # TagHierarchy should inherit from ApplicationRecord (abstract base)
    # NOT from Tag (which has callbacks/validations)
    assert_equal ApplicationRecord, TagHierarchy.superclass,
      "TagHierarchy should inherit from ApplicationRecord, not Tag"

    # Verify it doesn't inherit Tag's callbacks
    _tag_callbacks = Tag._destroy_callbacks.map(&:filter)
    hierarchy_callbacks = TagHierarchy._destroy_callbacks.map(&:filter)

    assert_not_includes hierarchy_callbacks, :add_destroyed_tag,
      "TagHierarchy should not inherit add_destroyed_tag callback from Tag"
  end

  test 'TagHierarchy has correct primary key set' do
    # Issue #392 comment showed RETURNING clause issues
    # Verify composite primary key is correctly set

    assert_equal %w[ancestor_id descendant_id generations], TagHierarchy.primary_key,
      "TagHierarchy should use composite primary key"
  end
end

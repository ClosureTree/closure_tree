# frozen_string_literal: true

require 'test_helper'

# Test that advisory lock names include scope values when scope option is configured
class ScopedAdvisoryLockTest < ActiveSupport::TestCase
  def test_advisory_lock_name_for_with_scope_includes_scope_value
    item = ScopedItem.new(user_id: 42)
    base = item._ct.advisory_lock_name
    assert_equal "#{base}_42", item._ct.advisory_lock_name_for(item)
  end

  def test_advisory_lock_name_for_different_scope_values_differ
    item_a = ScopedItem.new(user_id: 1)
    item_b = ScopedItem.new(user_id: 2)
    assert_not_equal item_a._ct.advisory_lock_name_for(item_a),
                     item_b._ct.advisory_lock_name_for(item_b)
  end

  def test_advisory_lock_name_for_same_scope_values_match
    item_a = ScopedItem.new(user_id: 7)
    item_b = ScopedItem.new(user_id: 7)
    assert_equal item_a._ct.advisory_lock_name_for(item_a),
                 item_b._ct.advisory_lock_name_for(item_b)
  end

  def test_advisory_lock_name_for_without_scope_returns_base
    tag = Tag.new
    base = tag._ct.advisory_lock_name
    assert_equal base, tag._ct.advisory_lock_name_for(tag)
  end

  def test_advisory_lock_name_for_nil_instance_returns_base
    item = ScopedItem.new(user_id: 1)
    assert_equal item._ct.advisory_lock_name, item._ct.advisory_lock_name_for(nil)
  end

  def test_advisory_lock_name_for_multi_scope
    item = MultiScopedItem.new(user_id: 10, group_id: 20)
    base = item._ct.advisory_lock_name
    assert_equal "#{base}_10_20", item._ct.advisory_lock_name_for(item)
  end
end

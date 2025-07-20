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
end

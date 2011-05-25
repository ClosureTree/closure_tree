require 'test_helper'

class TagTest < ActiveSupport::TestCase

  fixtures :tags

  def setup
    Tag.rebuild!
  end

  def test_roots
    roots = Tag.roots.to_a
    assert roots.include?(tags(:people))
    assert roots.include?(tags(:events))
    assert !roots.include?(tags(:child))
    assert tags(:people).root?
    assert !tags(:child).root?
  end

  def test_add_child
    sb = Tag.create!(:name => "Santa Barbara")
    assert sb.leaf?
    tags(:california).add_child sb
    assert sb.leaf?
    validate_city_tag sb
  end

  def test_add_through_children
    eg = Tag.create!(:name => "El Granada")
    assert eg.leaf?
    tags(:california).children << eg
    assert eg.leaf?
    validate_city_tag eg
  end

  def test_level
    assert_equal 0, tags(:grandparent).level
    assert_equal 1, tags(:parent).level
    assert_equal 2, tags(:child).level
  end

  def test_parent
    assert_equal nil, tags(:grandparent).parent
    assert_equal tags(:grandparent), tags(:parent).parent
    assert_equal tags(:parent), tags(:child).parent
  end

  def test_children
    assert tags(:grandparent).children.include? tags(:parent)
    assert tags(:parent).children.include? tags(:child)
    assert tags(:child).children.empty?
  end

  def test_ancestors
    assert_equal [tags(:parent), tags(:grandparent)], tags(:child).ancestors
    assert_equal [tags(:child), tags(:parent), tags(:grandparent)], tags(:child).self_and_ancestors
  end

  def test_ancestry_path
    assert_equal %w{grandparent parent child}, tags(:child).ancestry_names
  end

  def test_find_by_path
    # class method:
    assert_equal tags(:child), Tag.find_by_path(%w{grandparent parent child})
    assert_equal tags(:child), Tag.find_or_create_by_path(%w{grandparent parent child})
    # instance method:
    assert_equal tags(:child), tags(:parent).find_by_path(%w{child})
    assert_equal tags(:child), tags(:grandparent).find_by_path(%w{parent child})
    assert_nil tags(:parent).find_by_path(%w{child larvae})
  end

  def test_find_or_create_by_path
    # class method:
    assert_equal %w{events anniversary}, Tag.find_or_create_by_path(%w{events anniversary}).ancestry_names
    a = Tag.find_or_create_by_path(%w{a})
    assert_equal %w{a}, a.ancestry_names
    # instance method:
    assert_equal %w{a b c}, a.find_or_create_by_path(%w{b c}).ancestry_names
  end

  def test_descendants
    assert_equal [tags(:child)], tags(:parent).descendants
    assert_equal [tags(:parent), tags(:child)], tags(:parent).self_and_descendants

    assert_equal [tags(:parent), tags(:child)], tags(:grandparent).descendants
    assert_equal [tags(:grandparent), tags(:parent), tags(:child)], tags(:grandparent).self_and_descendants

    assert_equal "grandparent > parent > child", tags(:grandparent).self_and_descendants.collect { |t| t.name }.join(" > ")
  end

  def validate_city_tag city
    assert tags(:california).children.include?(city)
    assert_equal [tags(:california), tags(:united_states), tags(:places)], city.ancestors
    assert_equal [city, tags(:california), tags(:united_states), tags(:places)], city.self_and_ancestors
  end
end


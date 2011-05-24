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
    sb.reload
    assert sb.leaf?
    sb_ancestors = sb.ancestor_ids_with_generations
    assert_equal [[tags(:places).id, 3], [tags(:united_states).id, 2], [tags(:california).id, 1], [sb.id, 0]], sb_ancestors
  end

  def test_level
    assert_equal 0, tags(:grandparent).level
    assert_equal 1, tags(:parent).level
    assert_equal 2, tags(:child).level
  end

end


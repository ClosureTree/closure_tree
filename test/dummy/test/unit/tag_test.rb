require 'test_helper'

class TagTest < ActiveSupport::TestCase
  fixtures :tags

  def test_roots
    roots = Tag.roots.to_a
    assert(roots.include?(tags(:people)))
    assert(roots.include?(tags(:events)))
    assert(!roots.include?(tags(:child)))
  end

end


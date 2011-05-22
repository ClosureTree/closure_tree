require 'test_helper'

class ActsAsTreeTest < Test::Unit::TestCase
  def test_roots
    roots = Tag.roots
  end
end

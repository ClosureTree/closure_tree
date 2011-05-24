require 'test_helper'

class TagTest < ActiveSupport::TestCase
  fixtures :tags

  def test_roots
    roots = Tag.roots.to_a
    roots.each{|r| p r}
    assert_equal roots.size, 4
    assert roots.include?(tags(:people))
  end

end


# frozen_string_literal: true

require 'test_helper'

class CacheInvalidationTest < ActiveSupport::TestCase
  def setup
    Timecop.travel(10.seconds.ago) do
      # create a long tree with 2 branch
      @root = MenuItem.create(
        name: SecureRandom.hex(10)
      )
      2.times do
        parent = @root
        10.times do
          parent = parent.children.create(
            name: SecureRandom.hex(10)
          )
        end
      end
      @first_leaf = MenuItem.leaves.first
      @second_leaf = MenuItem.leaves.last
    end
  end

  test 'touch option should invalidate cache for all it ancestors' do
    old_time_stamp = @first_leaf.ancestors.pluck(:updated_at)
    @first_leaf.touch
    new_time_stamp = @first_leaf.ancestors.pluck(:updated_at)
    assert_not_equal old_time_stamp, new_time_stamp, 'Cache not invalidated for all ancestors'
  end

  test 'touch option should not invalidate cache for another branch' do
    old_time_stamp = @second_leaf.updated_at
    @first_leaf.touch
    new_time_stamp = @second_leaf.updated_at
    assert_equal old_time_stamp, new_time_stamp, 'Cache incorrectly invalidated for another branch'
  end
end

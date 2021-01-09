require 'spec_helper'

RSpec.describe 'cache invalidation', cache: true do
  before do
    Timecop.travel(10.seconds.ago) do
      #create a long tree with 2 branch
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

  describe 'touch option' do
    it 'should invalidate cache for all it ancestors' do
      old_time_stamp = @first_leaf.ancestors.pluck(:updated_at)
      @first_leaf.touch
      new_time_stamp = @first_leaf.ancestors.pluck(:updated_at)
      expect(old_time_stamp).to_not eq(new_time_stamp)
    end

    it 'should not invalidate cache for another branch' do
      old_time_stamp = @second_leaf.updated_at
      @first_leaf.touch
      new_time_stamp = @second_leaf.updated_at
      expect(old_time_stamp).to eq(new_time_stamp)
    end
  end
end

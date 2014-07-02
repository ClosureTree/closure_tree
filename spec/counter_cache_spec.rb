require 'spec_helper'

describe 'caching child count' do
  before do
    @root = MenuItem.create
  end

  describe 'cache_child_count option' do
    it 'should default to 0' do
      expect(@root.child_count).to eq(0)
    end

    it 'should keep track of the direct children as they are added and removed' do
      @root.children << MenuItem.new
      expect(@root.reload.child_count).to eq(1)
      MenuItem.create(parent: @root)
      expect(@root.reload.child_count).to eq(2)
      @root.children.first.destroy
      expect(@root.reload.child_count).to eq(1)
    end

    it 'should not count children of children' do
      child_node = MenuItem.new
      child_node.children << MenuItem.new
      @root.children << child_node

      expect(@root.reload.child_count).to eq(1)
    end
  end
end

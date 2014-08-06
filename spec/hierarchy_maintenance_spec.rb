require 'spec_helper'

describe ClosureTree::HierarchyMaintenance do
  describe '.rebuild!' do
    it 'rebuild tree' do
      20.times do |counter|
        Metal.create(:value => "Nitro-#{counter}", parent: Metal.all.sample)
      end
      hierarchy_count = MetalHierarchy.count
      expect(hierarchy_count).to be > (20*2)-1 # shallowest-possible case, where all children use the first root
      MetalHierarchy.delete_all
      Metal.rebuild!
      expect(MetalHierarchy.count).to eq(hierarchy_count)
    end
  end
end

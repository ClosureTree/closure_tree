# frozen_string_literal: true

require 'test_helper'

describe ClosureTree::HierarchyMaintenance do
  describe '.rebuild!' do
    it 'rebuild tree' do
      20.times do |counter|
        Metal.create(value: "Nitro-#{counter}", parent: Metal.all.sample)
      end
      hierarchy_count = MetalHierarchy.count
      assert_operator hierarchy_count, :>, (20 * 2) - 1 # shallowest-possible case, where all children use the first root
      MetalHierarchy.delete_all
      Metal.rebuild!
      assert_equal MetalHierarchy.count, hierarchy_count
    end
  end

  describe '.cleanup!' do
    before do
      @parent = Metal.create(value: 'parent metal')
      @child = Metal.create(value: 'child metal', parent: @parent)
      MetalHierarchy.delete_all
      Metal.rebuild!
    end

    describe 'when an element is deleted' do
      it 'should delete the child hierarchies' do
        @child.delete

        Metal.cleanup!

        assert_empty MetalHierarchy.where(descendant_id: @child.id)
        assert_empty MetalHierarchy.where(ancestor_id: @child.id)
      end

      it 'should not delete the parent hierarchies' do
        @child.delete
        Metal.cleanup!
        assert_equal 1, MetalHierarchy.where(ancestor_id: @parent.id).size
      end

      it 'should not delete other hierarchies' do
        other_parent = Metal.create(value: 'other parent metal')
        other_child = Metal.create(value: 'other child metal', parent: other_parent)
        Metal.rebuild!

        @child.delete
        Metal.cleanup!

        assert_equal 2, MetalHierarchy.where(ancestor_id: other_parent.id).size
        assert_equal 2, MetalHierarchy.where(descendant_id: other_child.id).size
      end
    end
  end
end

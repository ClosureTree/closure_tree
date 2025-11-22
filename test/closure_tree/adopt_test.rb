# frozen_string_literal: true

require 'test_helper'

def run_adopt_tests_for(model_class)
  describe "#{model_class} with dependent: :adopt" do
    before do
      model_class.delete_all
      model_class.hierarchy_class.delete_all
    end

    it 'moves children to grandparent when parent is destroyed and updates hierarchy table' do
      p1 = model_class.create!(name: 'p1')
      p2 = model_class.create!(name: 'p2', parent: p1)
      p3 = model_class.create!(name: 'p3', parent: p2)
      p4 = model_class.create!(name: 'p4', parent: p3)

      # Verify initial structure: p1 -> p2 -> p3 -> p4
      assert_equal p2, p3.parent
      assert_equal p3, p4.parent
      assert_equal p1, p2.parent

      # Verify initial hierarchy table entries
      hierarchy = model_class.hierarchy_class
      assert hierarchy.where(ancestor_id: p1.id, descendant_id: p4.id, generations: 3).exists?
      assert hierarchy.where(ancestor_id: p2.id, descendant_id: p4.id, generations: 2).exists?
      assert hierarchy.where(ancestor_id: p3.id, descendant_id: p4.id, generations: 1).exists?
      assert hierarchy.where(ancestor_id: p3.id, descendant_id: p3.id, generations: 0).exists?

      # Destroy p3
      p3.destroy

      # After destroying p3, p4 should be adopted by p2 (p3's parent)
      p4.reload
      p2.reload
      assert_equal p2, p4.parent, 'p4 should be moved to p2 (grandparent)'
      assert_equal p1, p2.parent, 'p2 should still have p1 as parent'
      assert_equal [p4], p2.children.to_a, 'p2 should have p4 as child'

      # Verify hierarchy table was updated correctly
      # p3 should be removed from hierarchy
      assert_empty hierarchy.where(ancestor_id: p3.id)
      assert_empty hierarchy.where(descendant_id: p3.id)

      # p4 should now have p2 as direct parent (generations: 1)
      assert hierarchy.where(ancestor_id: p2.id, descendant_id: p4.id, generations: 1).exists?
      # p4 should have p1 as ancestor (generations: 2)
      assert hierarchy.where(ancestor_id: p1.id, descendant_id: p4.id, generations: 2).exists?
      # p4 should have itself (generations: 0)
      assert hierarchy.where(ancestor_id: p4.id, descendant_id: p4.id, generations: 0).exists?
    end

    it 'moves children to root when parent without grandparent is destroyed and updates hierarchy table' do
      p1 = model_class.create!(name: 'p1')
      p2 = model_class.create!(name: 'p2', parent: p1)
      p3 = model_class.create!(name: 'p3', parent: p2)

      # Verify initial structure: p1 -> p2 -> p3
      assert_equal p1, p2.parent
      assert_equal p2, p3.parent

      hierarchy = model_class.hierarchy_class
      initial_p2_hierarchies = hierarchy.where(ancestor_id: p2.id).count
      initial_p3_hierarchies = hierarchy.where(descendant_id: p3.id).count

      # Destroy p1 (root node)
      p1.destroy

      # After destroying p1, p2 should become root, and p3 should still be child of p2
      p2.reload
      p3.reload
      assert_nil p2.parent, 'p2 should become root'
      assert_equal p2, p3.parent, 'p3 should still have p2 as parent'
      assert p2.root?, 'p2 should be a root node'
      assert_equal [p3], p2.children.to_a, 'p2 should have p3 as child'

      # Verify hierarchy table: p1 should be removed
      assert_empty hierarchy.where(ancestor_id: p1.id)
      assert_empty hierarchy.where(descendant_id: p1.id)

      # p2 should now be a root (no ancestors)
      assert hierarchy.where(ancestor_id: p2.id, descendant_id: p2.id, generations: 0).exists?
      # p3 should still have p2 as parent
      assert hierarchy.where(ancestor_id: p2.id, descendant_id: p3.id, generations: 1).exists?
    end

    it 'handles multiple children being adopted and updates hierarchy table' do
      p1 = model_class.create!(name: 'p1')
      p2 = model_class.create!(name: 'p2', parent: p1)
      c1 = model_class.create!(name: 'c1', parent: p2)
      c2 = model_class.create!(name: 'c2', parent: p2)
      c3 = model_class.create!(name: 'c3', parent: p2)

      # Verify initial structure: p1 -> p2 -> [c1, c2, c3]
      assert_equal [c1, c2, c3].sort, p2.children.to_a.sort

      hierarchy = model_class.hierarchy_class
      # Verify initial hierarchy: all children should have p1 and p2 as ancestors
      [c1, c2, c3].each do |child|
        assert hierarchy.where(ancestor_id: p1.id, descendant_id: child.id, generations: 2).exists?
        assert hierarchy.where(ancestor_id: p2.id, descendant_id: child.id, generations: 1).exists?
      end

      # Destroy p2
      p2.destroy

      # All children should be adopted by p1
      p1.reload
      c1.reload
      c2.reload
      c3.reload

      assert_equal p1, c1.parent, 'c1 should be moved to p1'
      assert_equal p1, c2.parent, 'c2 should be moved to p1'
      assert_equal p1, c3.parent, 'c3 should be moved to p1'
      assert_equal [c1, c2, c3].sort, p1.children.to_a.sort, 'p1 should have all three children'

      # Verify hierarchy table: p2 should be removed
      assert_empty hierarchy.where(ancestor_id: p2.id)
      assert_empty hierarchy.where(descendant_id: p2.id)

      # All children should now have p1 as direct parent (generations: 1)
      [c1, c2, c3].each do |child|
        assert hierarchy.where(ancestor_id: p1.id, descendant_id: child.id, generations: 1).exists?
        # Should not have p2 in their ancestry anymore
        assert_empty hierarchy.where(ancestor_id: p2.id, descendant_id: child.id)
      end
    end

    it 'maintains hierarchy relationships after adoption' do
      p1 = model_class.create!(name: 'p1')
      p2 = model_class.create!(name: 'p2', parent: p1)
      p3 = model_class.create!(name: 'p3', parent: p2)
      p4 = model_class.create!(name: 'p4', parent: p3)
      p5 = model_class.create!(name: 'p5', parent: p4)

      # Verify initial structure: p1 -> p2 -> p3 -> p4 -> p5
      assert_equal %w[p1 p2 p3 p4 p5], p5.ancestry_path

      hierarchy = model_class.hierarchy_class
      # Verify p5 has all ancestors in hierarchy
      assert hierarchy.where(ancestor_id: p1.id, descendant_id: p5.id, generations: 4).exists?
      assert hierarchy.where(ancestor_id: p2.id, descendant_id: p5.id, generations: 3).exists?
      assert hierarchy.where(ancestor_id: p3.id, descendant_id: p5.id, generations: 2).exists?
      assert hierarchy.where(ancestor_id: p4.id, descendant_id: p5.id, generations: 1).exists?

      # Destroy p3
      p3.destroy

      # After adoption, p4 and p5 should still maintain their relationship
      p4.reload
      p5.reload
      assert_equal p2, p4.parent, 'p4 should be adopted by p2'
      assert_equal p4, p5.parent, 'p5 should still have p4 as parent'
      assert_equal %w[p1 p2 p4 p5], p5.ancestry_path, 'ancestry path should be updated correctly'

      # Verify hierarchy table: p3 should be removed
      assert_empty hierarchy.where(ancestor_id: p3.id)
      assert_empty hierarchy.where(descendant_id: p3.id)

      # p5 should now have p2 as ancestor (generations: 2) and p4 as parent (generations: 1)
      assert hierarchy.where(ancestor_id: p2.id, descendant_id: p5.id, generations: 2).exists?
      assert hierarchy.where(ancestor_id: p4.id, descendant_id: p5.id, generations: 1).exists?
      assert hierarchy.where(ancestor_id: p1.id, descendant_id: p5.id, generations: 3).exists?
      # p5 should not have p3 in its ancestry anymore
      assert_empty hierarchy.where(ancestor_id: p3.id, descendant_id: p5.id)
    end

    it 'handles deep nested structures correctly and updates hierarchy table' do
      root = model_class.create!(name: 'root')
      level1 = model_class.create!(name: 'level1', parent: root)
      level2 = model_class.create!(name: 'level2', parent: level1)
      level3 = model_class.create!(name: 'level3', parent: level2)
      level4 = model_class.create!(name: 'level4', parent: level3)

      hierarchy = model_class.hierarchy_class
      # Verify initial hierarchy for level4
      assert hierarchy.where(ancestor_id: root.id, descendant_id: level4.id, generations: 4).exists?
      assert hierarchy.where(ancestor_id: level1.id, descendant_id: level4.id, generations: 3).exists?
      assert hierarchy.where(ancestor_id: level2.id, descendant_id: level4.id, generations: 2).exists?
      assert hierarchy.where(ancestor_id: level3.id, descendant_id: level4.id, generations: 1).exists?

      # Destroy level2
      level2.destroy

      # level3 should be adopted by level1, and level4 should still be child of level3
      level1.reload
      level3.reload
      level4.reload

      assert_equal level1, level3.parent, 'level3 should be adopted by level1'
      assert_equal level3, level4.parent, 'level4 should still have level3 as parent'
      assert_equal %w[root level1 level3 level4], level4.ancestry_path

      # Verify hierarchy table: level2 should be removed
      assert_empty hierarchy.where(ancestor_id: level2.id)
      assert_empty hierarchy.where(descendant_id: level2.id)

      # level4 should now have correct ancestry without level2
      assert hierarchy.where(ancestor_id: root.id, descendant_id: level4.id, generations: 3).exists?
      assert hierarchy.where(ancestor_id: level1.id, descendant_id: level4.id, generations: 2).exists?
      assert hierarchy.where(ancestor_id: level3.id, descendant_id: level4.id, generations: 1).exists?
      # level4 should not have level2 in its ancestry anymore
      assert_empty hierarchy.where(ancestor_id: level2.id, descendant_id: level4.id)
    end

    it 'handles destroying a node with no children' do
      p1 = model_class.create!(name: 'p1')
      p2 = model_class.create!(name: 'p2', parent: p1)
      leaf = model_class.create!(name: 'leaf', parent: p2)

      hierarchy = model_class.hierarchy_class
      initial_count = hierarchy.count

      # Destroy leaf (has no children)
      leaf.destroy

      # Should not raise any errors
      p1.reload
      p2.reload
      assert_equal [p2], p1.children.to_a
      assert_equal [], p2.children.to_a

      # Hierarchy should be cleaned up
      assert_empty hierarchy.where(ancestor_id: leaf.id)
      assert_empty hierarchy.where(descendant_id: leaf.id)
    end

    it 'works with find_or_create_by_path' do
      level3 = model_class.find_or_create_by_path(%w[root level1 level2 level3])
      root = level3.root
      level1 = root.children.find_by(name: 'level1')
      level2 = level1.children.find_by(name: 'level2')

      hierarchy = model_class.hierarchy_class
      # Verify initial hierarchy
      assert hierarchy.where(ancestor_id: root.id, descendant_id: level3.id).exists?
      assert hierarchy.where(ancestor_id: level2.id, descendant_id: level3.id, generations: 1).exists?

      # Destroy level2
      level2.destroy

      # level3 should be adopted by level1
      level1.reload
      level3.reload
      assert_equal level1, level3.parent
      assert_equal %w[root level1 level3], level3.ancestry_path

      # Verify hierarchy table
      assert_empty hierarchy.where(ancestor_id: level2.id)
      assert hierarchy.where(ancestor_id: level1.id, descendant_id: level3.id, generations: 1).exists?
      assert hierarchy.where(ancestor_id: root.id, descendant_id: level3.id, generations: 2).exists?
    end
  end
end

# Test with PostgreSQL
if postgresql?(ApplicationRecord.connection)
  run_adopt_tests_for(AdoptableTag)
end

# Test with MySQL
if mysql?(MysqlRecord.connection)
  run_adopt_tests_for(MysqlAdoptableTag)
end

# Test with SQLite
if sqlite?(SqliteRecord.connection)
  run_adopt_tests_for(MemoryAdoptableTag)
end

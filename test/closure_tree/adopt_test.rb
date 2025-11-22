# frozen_string_literal: true

require 'test_helper'

describe 'AdoptableTag with dependent: :adopt' do
  before do
    AdoptableTag.delete_all
    AdoptableTag.hierarchy_class.delete_all
  end

  it 'moves children to grandparent when parent is destroyed' do
    p1 = AdoptableTag.create!(name: 'p1')
    p2 = AdoptableTag.create!(name: 'p2', parent: p1)
    p3 = AdoptableTag.create!(name: 'p3', parent: p2)
    p4 = AdoptableTag.create!(name: 'p4', parent: p3)

    # Verify initial structure: p1 -> p2 -> p3 -> p4
    assert_equal p2, p3.parent
    assert_equal p3, p4.parent
    assert_equal p1, p2.parent

    # Destroy p3
    p3.destroy

    # After destroying p3, p4 should be adopted by p2 (p3's parent)
    p4.reload
    p2.reload
    assert_equal p2, p4.parent, 'p4 should be moved to p2 (grandparent)'
    assert_equal p1, p2.parent, 'p2 should still have p1 as parent'
    assert_equal [p4], p2.children.to_a, 'p2 should have p4 as child'
  end

  it 'moves children to root when parent without grandparent is destroyed' do
    p1 = AdoptableTag.create!(name: 'p1')
    p2 = AdoptableTag.create!(name: 'p2', parent: p1)
    p3 = AdoptableTag.create!(name: 'p3', parent: p2)

    # Verify initial structure: p1 -> p2 -> p3
    assert_equal p1, p2.parent
    assert_equal p2, p3.parent

    # Destroy p1 (root node)
    p1.destroy

    # After destroying p1, p2 should become root, and p3 should still be child of p2
    p2.reload
    p3.reload
    assert_nil p2.parent, 'p2 should become root'
    assert_equal p2, p3.parent, 'p3 should still have p2 as parent'
    assert p2.root?, 'p2 should be a root node'
    assert_equal [p3], p2.children.to_a, 'p2 should have p3 as child'
  end

  it 'handles multiple children being adopted' do
    p1 = AdoptableTag.create!(name: 'p1')
    p2 = AdoptableTag.create!(name: 'p2', parent: p1)
    c1 = AdoptableTag.create!(name: 'c1', parent: p2)
    c2 = AdoptableTag.create!(name: 'c2', parent: p2)
    c3 = AdoptableTag.create!(name: 'c3', parent: p2)

    # Verify initial structure: p1 -> p2 -> [c1, c2, c3]
    assert_equal [c1, c2, c3].sort, p2.children.to_a.sort

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
  end

  it 'maintains hierarchy relationships after adoption' do
    p1 = AdoptableTag.create!(name: 'p1')
    p2 = AdoptableTag.create!(name: 'p2', parent: p1)
    p3 = AdoptableTag.create!(name: 'p3', parent: p2)
    p4 = AdoptableTag.create!(name: 'p4', parent: p3)
    p5 = AdoptableTag.create!(name: 'p5', parent: p4)

    # Verify initial structure: p1 -> p2 -> p3 -> p4 -> p5
    assert_equal %w[p1 p2 p3 p4 p5], p5.ancestry_path

    # Destroy p3
    p3.destroy

    # After adoption, p4 and p5 should still maintain their relationship
    p4.reload
    p5.reload
    assert_equal p2, p4.parent, 'p4 should be adopted by p2'
    assert_equal p4, p5.parent, 'p5 should still have p4 as parent'
    assert_equal %w[p1 p2 p4 p5], p5.ancestry_path, 'ancestry path should be updated correctly'
  end

  it 'handles deep nested structures correctly' do
    root = AdoptableTag.create!(name: 'root')
    level1 = AdoptableTag.create!(name: 'level1', parent: root)
    level2 = AdoptableTag.create!(name: 'level2', parent: level1)
    level3 = AdoptableTag.create!(name: 'level3', parent: level2)
    level4 = AdoptableTag.create!(name: 'level4', parent: level3)

    # Destroy level2
    level2.destroy

    # level3 should be adopted by level1, and level4 should still be child of level3
    level1.reload
    level3.reload
    level4.reload

    assert_equal level1, level3.parent, 'level3 should be adopted by level1'
    assert_equal level3, level4.parent, 'level4 should still have level3 as parent'
    assert_equal %w[root level1 level3 level4], level4.ancestry_path
  end

  it 'handles destroying a node with no children' do
    p1 = AdoptableTag.create!(name: 'p1')
    p2 = AdoptableTag.create!(name: 'p2', parent: p1)
    leaf = AdoptableTag.create!(name: 'leaf', parent: p2)

    # Destroy leaf (has no children)
    leaf.destroy

    # Should not raise any errors
    p1.reload
    p2.reload
    assert_equal [p2], p1.children.to_a
    assert_equal [], p2.children.to_a
  end

  it 'works with find_or_create_by_path' do
    level3 = AdoptableTag.find_or_create_by_path(%w[root level1 level2 level3])
    root = level3.root
    level1 = root.children.find_by(name: 'level1')
    level2 = level1.children.find_by(name: 'level2')

    # Destroy level2
    level2.destroy

    # level3 should be adopted by level1
    level1.reload
    level3.reload
    assert_equal level1, level3.parent
    assert_equal %w[root level1 level3], level3.ancestry_path
  end
end



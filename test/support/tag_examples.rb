# frozen_string_literal: true

require 'active_support/concern'

module TagExamples
  extend ActiveSupport::Concern

  included do
    def setup
      super
      @tag_class = self.class.const_get(:TAG_CLASS) || Tag
      @tag_hierarchy_class = @tag_class.hierarchy_class
      # Clean up any existing data to ensure test isolation
      @tag_class.delete_all
      @tag_hierarchy_class.delete_all
    end

    define_method 'test_should_build_hierarchy_classname_correctly' do
      assert_equal @tag_hierarchy_class, @tag_class.hierarchy_class
      assert_equal @tag_hierarchy_class.to_s, @tag_class._ct.hierarchy_class_name
      assert_equal @tag_hierarchy_class.to_s, @tag_class._ct.short_hierarchy_class_name
    end

    define_method 'test_should_have_a_correct_parent_column_name' do
      expected_parent_column_name = @tag_class == UuidTag ? 'parent_uuid' : 'parent_id'
      assert_equal expected_parent_column_name, @tag_class._ct.parent_column_name
    end

    define_method 'test_should_return_no_entities_when_db_is_empty' do
      assert_empty @tag_class.roots
      assert_empty @tag_class.leaves
    end

    define_method 'test_find_or_create_by_path_with_strings' do
      a = @tag_class.create!(name: 'a')
      assert_equal(%w[a b c], a.find_or_create_by_path(%w[b c]).ancestry_path)
    end

    define_method 'test_find_or_create_by_path_with_hashes' do
      a = @tag_class.create!(name: 'a', title: 'A')
      subject = a.find_or_create_by_path([
                                           { name: 'b', title: 'B' },
                                           { name: 'c', title: 'C' }
                                         ])
      assert_equal(%w[a b c], subject.ancestry_path)
      assert_equal(%w[C B A], subject.self_and_ancestors.map(&:title))
    end

    define_method 'test_single_tag_should_be_a_leaf_and_root' do
      tag = @tag_class.create!(name: 'tag')
      assert tag.leaf?
      assert tag.root?
      assert_nil tag.parent
      assert_equal [tag], @tag_class.all
      assert_equal [tag], @tag_class.roots
      assert_equal [tag], @tag_class.leaves
    end

    define_method 'test_should_not_find_tag_with_invalid_path_arguments' do
      tag = @tag_class.create!(name: 'tag')
      assert_nil @tag_class.find_by_path([''])
      assert_nil @tag_class.find_by_path([])
      assert_nil @tag_class.find_by_path(nil)
      assert_nil @tag_class.find_by_path('')
      assert_nil @tag_class.find_by_path([nil])
      assert_nil @tag_class.find_by_path([tag.name, ''])
      assert_nil @tag_class.find_by_path([tag.name, nil])
    end

    define_method 'test_should find tag by valid path' do
      tag = @tag_class.create!(name: 'tag')
      assert_equal tag, @tag_class.find_by_path([tag.name])
      assert_equal tag, @tag_class.find_by_path(tag.name)
    end

    define_method 'test_adds children through add_child' do
      tag = @tag_class.create!(name: 'tag')
      child = @tag_class.create!(name: 'tag 2')
      tag.add_child child

      assert tag.root?
      refute tag.leaf?
      refute child.root?
      assert child.leaf?
      assert_equal tag, child.reload.parent
      assert_equal [child], tag.reload.children.to_a
    end

    define_method 'test_adds children through collection' do
      tag = @tag_class.create!(name: 'tag')
      child = @tag_class.create!(name: 'tag 2')
      tag.children << child

      assert tag.root?
      refute tag.leaf?
      refute child.root?
      assert child.leaf?
      assert_equal tag, child.reload.parent
      assert_equal [child], tag.reload.children.to_a
    end

    define_method 'test_returns simple root and leaf with 2 tags' do
      root = @tag_class.create!(name: 'root')
      leaf = root.add_child(@tag_class.create!(name: 'leaf'))

      assert_equal [root], @tag_class.roots
      assert_equal [leaf], @tag_class.leaves
      assert_equal [leaf.id], root.child_ids
      assert_empty leaf.child_ids
    end

    define_method 'test_3 tag collection.create hierarchy' do
      root = @tag_class.create! name: 'root'
      mid = root.children.create! name: 'mid'
      leaf = mid.children.create! name: 'leaf'
      DestroyedTag.delete_all

      assert_equal [root, mid, leaf].sort, @tag_class.all.to_a.sort
      assert_equal [root], @tag_class.roots
      assert_equal [leaf], @tag_class.leaves
    end

    define_method 'test_deletes leaves' do
      root = @tag_class.create! name: 'root'
      mid = root.children.create! name: 'mid'
      mid.children.create! name: 'leaf'
      DestroyedTag.delete_all

      @tag_class.leaves.destroy_all
      assert_equal [root], @tag_class.roots
      assert_equal [mid], @tag_class.leaves
    end

    define_method 'test_deletes everything when deleting roots' do
      root = @tag_class.create! name: 'root'
      mid = root.children.create! name: 'mid'
      mid.children.create! name: 'leaf'
      DestroyedTag.delete_all

      @tag_class.roots.destroy_all
      assert_empty @tag_class.all
      assert_empty @tag_class.roots
      assert_empty @tag_class.leaves
      assert_equal %w[root mid leaf].sort, DestroyedTag.all.map(&:name).sort
    end

    define_method 'test_fixes self_and_ancestors properly on reparenting' do
      root = @tag_class.create! name: 'root'
      mid = root.children.create! name: 'mid'
      mid.children.create! name: 'leaf'

      t = @tag_class.create! name: 'moar leaf'
      assert_equal [t], t.self_and_ancestors.to_a
      mid.children << t
      assert_equal [t, mid, root], t.self_and_ancestors.to_a
    end

    define_method 'test_prevents ancestor loops' do
      root = @tag_class.create! name: 'root'
      mid = root.children.create! name: 'mid'
      leaf = mid.children.create! name: 'leaf'

      leaf.add_child root
      refute root.valid?
      assert_includes root.reload.descendants, leaf
    end

    define_method 'test_moves non-leaves' do
      root = @tag_class.create! name: 'root'
      mid = root.children.create! name: 'mid'
      leaf = mid.children.create! name: 'leaf'

      new_root = @tag_class.create! name: 'new_root'
      new_root.children << mid
      assert_empty root.reload.descendants
      assert_equal [mid, leaf], new_root.descendants
      assert_equal %w[new_root mid leaf], leaf.reload.ancestry_path
    end

    define_method 'test_moves leaves' do
      root = @tag_class.create! name: 'root'
      mid = root.children.create! name: 'mid'
      leaf = mid.children.create! name: 'leaf'

      new_root = @tag_class.create! name: 'new_root'
      new_root.children << leaf
      assert_equal [leaf], new_root.descendants
      assert_equal [mid], root.reload.descendants
      assert_equal %w[new_root leaf], leaf.reload.ancestry_path
    end

    define_method 'test_3 tag explicit_create hierarchy' do
      root = @tag_class.create!(name: 'root')
      mid = root.add_child(@tag_class.create!(name: 'mid'))
      leaf = mid.add_child(@tag_class.create!(name: 'leaf'))

      assert_equal [root, mid, leaf].sort, @tag_class.all.to_a.sort
      assert_equal [root], @tag_class.roots
      assert_equal [leaf], @tag_class.leaves
    end

    define_method 'test_prevents parental loops from torso' do
      root = @tag_class.create!(name: 'root')
      mid = root.add_child(@tag_class.create!(name: 'mid'))
      leaf = mid.add_child(@tag_class.create!(name: 'leaf'))

      mid.children << root
      refute root.valid?
      assert_equal [leaf], mid.reload.children
    end

    define_method 'test_prevents parental loops from toes' do
      root = @tag_class.create!(name: 'root')
      mid = root.add_child(@tag_class.create!(name: 'mid'))
      leaf = mid.add_child(@tag_class.create!(name: 'leaf'))

      leaf.children << root
      refute root.valid?
      assert_empty leaf.reload.children
    end

    define_method 'test_supports re-parenting' do
      root = @tag_class.create!(name: 'root')
      mid = root.add_child(@tag_class.create!(name: 'mid'))
      leaf = mid.add_child(@tag_class.create!(name: 'leaf'))

      root.children << leaf
      assert_equal [leaf, mid], @tag_class.leaves
    end

    define_method 'test_cleans up hierarchy references for leaves' do
      root = @tag_class.create!(name: 'root')
      mid = root.add_child(@tag_class.create!(name: 'mid'))
      leaf = mid.add_child(@tag_class.create!(name: 'leaf'))

      leaf.destroy
      assert_empty @tag_hierarchy_class.where(ancestor_id: leaf.id)
      assert_empty @tag_hierarchy_class.where(descendant_id: leaf.id)
    end

    define_method 'test_cleans up hierarchy references' do
      root = @tag_class.create!(name: 'root')
      mid = root.add_child(@tag_class.create!(name: 'mid'))
      mid.add_child(@tag_class.create!(name: 'leaf'))

      mid.destroy
      assert_empty @tag_hierarchy_class.where(ancestor_id: mid.id)
      assert_empty @tag_hierarchy_class.where(descendant_id: mid.id)
      assert root.reload.root?
      root_hiers = root.ancestor_hierarchies.to_a
      assert_equal 1, root_hiers.size
      assert_equal root_hiers, @tag_hierarchy_class.where(ancestor_id: root.id)
      assert_equal root_hiers, @tag_hierarchy_class.where(descendant_id: root.id)
    end

    define_method 'test_hierarchy models have different hash codes' do
      root = @tag_class.create!(name: 'root')
      mid = root.add_child(@tag_class.create!(name: 'mid'))
      mid.add_child(@tag_class.create!(name: 'leaf'))

      hashes = @tag_hierarchy_class.all.map(&:hash)
      assert_equal hashes.uniq.sort, hashes.sort
    end

    define_method 'test_equal hierarchy models have same hash code' do
      root = @tag_class.create!(name: 'root')
      root.add_child(@tag_class.create!(name: 'mid'))

      assert_equal @tag_hierarchy_class.first.hash, @tag_hierarchy_class.first.hash
    end

    define_method 'test_performs as the readme says' do
      grandparent = @tag_class.create(name: 'Grandparent')
      parent = grandparent.children.create(name: 'Parent')
      child1 = @tag_class.create(name: 'First Child', parent: parent)
      child2 = @tag_class.new(name: 'Second Child')
      parent.children << child2
      child3 = @tag_class.new(name: 'Third Child')
      parent.add_child child3

      assert_equal(%w[Grandparent Parent], parent.ancestry_path)
      assert_equal(['Grandparent', 'Parent', 'First Child'], child1.ancestry_path)
      assert_equal(['Grandparent', 'Parent', 'Second Child'], child2.ancestry_path)
      assert_equal(['Grandparent', 'Parent', 'Third Child'], child3.ancestry_path)

      d = @tag_class.find_or_create_by_path %w[a b c d]
      h = @tag_class.find_or_create_by_path %w[e f g h]
      e = h.root
      d.add_child(e)
      assert_equal %w[a b c d e f g h], h.ancestry_path
    end

    define_method 'test_roots sort alphabetically' do
      expected = ('a'..'z').to_a
      expected.shuffle.each { |ea| @tag_class.create!(name: ea) }
      assert_equal expected, @tag_class.roots.collect(&:name)
    end

    define_method 'test_finds global roots in simple tree' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a1 b1 c1c]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      a1, a2, a3, = @tag_class.all.sort_by(&:name)
      expected_roots = [a1, a2, a3]

      assert_equal expected_roots.sort, @tag_class.roots.to_a.sort
    end

    define_method 'test_returns root? for roots' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      a1, a2, a3 = @tag_class.all.sort_by(&:name).select(&:root?)
      [a1, a2, a3].each { |ea| assert(ea.root?) }
    end

    define_method 'test_does not return root? for non-roots' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a2 b2]

      _, _, b1, b2, c1a = @tag_class.all.sort_by(&:name)
      [b1, b2, c1a].each { |ea| refute(ea.root?) }
    end

    define_method 'test_returns the correct root' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a2 b2]

      a1, a2, b1, b2, c1a, c1b = @tag_class.all.sort_by(&:name)

      { a1 => a1, a2 => a2, b1 => a1, b2 => a2, c1a => a1, c1b => a1 }.each do |node, root|
        assert_equal(root, node.root)
      end
    end

    define_method 'test_assembles global leaves' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a1 b1 c1c]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      _, _, a3, _, b1b, b2, c1a, c1b, c1c = @tag_class.all.sort_by(&:name)
      expected_leaves = [c1a, c1b, c1c, b1b, b2, a3]

      assert_equal expected_leaves.sort, @tag_class.leaves.to_a.sort
    end

    define_method 'test_assembles siblings properly' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a1 b1 c1c]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      a1, a2, a3, b1, b1b, _, c1a, c1b, c1c = @tag_class.all.sort_by(&:name)
      expected_siblings = [[a1, a2, a3], [b1, b1b], [c1a, c1b, c1c]]
      expected_only_children = @tag_class.all - expected_siblings.flatten

      expected_siblings.each do |siblings|
        siblings.each do |ea|
          assert_equal siblings.sort, ea.self_and_siblings.to_a.sort
          assert_equal((siblings - [ea]).sort, ea.siblings.to_a.sort)
        end
      end

      expected_only_children.each do |ea|
        assert_equal [], ea.siblings
      end
    end

    define_method 'test_assembles before_siblings' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a1 b1 c1c]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      a1, a2, a3, b1, b1b, _, c1a, c1b, c1c = @tag_class.all.sort_by(&:name)
      expected_siblings = [[a1, a2, a3], [b1, b1b], [c1a, c1b, c1c]]

      expected_siblings.each do |siblings|
        (siblings.size - 1).times do |i|
          target = siblings[i]
          expected_before = siblings.first(i)
          assert_equal expected_before, target.siblings_before.to_a
        end
      end
    end

    define_method 'test_assembles after_siblings' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a1 b1 c1c]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      a1, a2, a3, b1, b1b, _, c1a, c1b, c1c = @tag_class.all.sort_by(&:name)
      expected_siblings = [[a1, a2, a3], [b1, b1b], [c1a, c1b, c1c]]

      expected_siblings.each do |siblings|
        (siblings.size - 1).times do |i|
          target = siblings[i]
          expected_after = siblings.last(siblings.size - 1 - i)
          assert_equal expected_after, target.siblings_after.to_a
        end
      end
    end

    define_method 'test_assembles instance leaves' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a1 b1 c1c]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      a1, a2, a3, b1, b1b, b2, c1a, c1b, c1c = @tag_class.all.sort_by(&:name)
      expected_leaves = [c1a, c1b, c1c, b1b, b2, a3]

      { a1 => [b1b, c1a, c1b, c1c], b1 => [c1a, c1b, c1c], a2 => [b2] }.each do |node, leaves|
        assert_equal leaves, node.leaves.to_a
      end

      expected_leaves.each { |ea| assert_equal [ea], ea.leaves.to_a }
    end

    define_method 'test_returns leaf? for leaves' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      _, _, a3, _, b1b, b2, c1a = @tag_class.all.sort_by(&:name)
      expected_leaves = [c1a, b1b, b2, a3]

      expected_leaves.each { |ea| assert ea.leaf? }
    end

    define_method 'test_can move roots' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      _, a2, a3, _, b2, c1a = @tag_class.all.sort_by(&:name)

      c1a.children << a2
      b2.reload.children << a3
      assert_equal %w[a1 b1 c1a a2 b2 a3], a3.reload.ancestry_path
    end

    define_method 'test_cascade-deletes from roots' do
      @tag_class.find_or_create_by_path %w[a1 b1 c1a]
      @tag_class.find_or_create_by_path %w[a1 b1 c1b]
      @tag_class.find_or_create_by_path %w[a1 b1 c1c]
      @tag_class.find_or_create_by_path %w[a1 b1b]
      @tag_class.find_or_create_by_path %w[a2 b2]
      @tag_class.find_or_create_by_path %w[a3]

      a1 = @tag_class.all.min_by(&:name)

      victim_names = a1.self_and_descendants.map(&:name)
      survivor_names = @tag_class.all.map(&:name) - victim_names
      a1.destroy
      assert_equal survivor_names, @tag_class.all.map(&:name)
    end

    define_method 'test_with_ancestor works with no rows' do
      assert_empty @tag_class.with_ancestor.to_a
    end

    define_method 'test_with_ancestor finds only children' do
      c = @tag_class.find_or_create_by_path %w[A B C]
      a = c.parent.parent
      b = c.parent
      @tag_class.find_or_create_by_path %w[D E]
      assert_equal [b, c], @tag_class.with_ancestor(a).to_a
    end

    define_method 'test_with_ancestor limits subsequent where clauses' do
      a1c = @tag_class.find_or_create_by_path %w[A1 B C]
      a2c = @tag_class.find_or_create_by_path %w[A2 B C]
      refute_equal a2c, a1c
      assert_equal [a1c, a2c].sort, @tag_class.where(name: 'C').to_a.sort
      assert_equal [a1c], @tag_class.with_ancestor(a1c.parent.parent).where(name: 'C').to_a.sort
    end

    define_method 'test_with_descendant works with no rows' do
      assert_empty @tag_class.with_descendant.to_a
    end

    define_method 'test_with_descendant finds only parents' do
      c = @tag_class.find_or_create_by_path %w[A B C]
      a = c.parent.parent
      b = c.parent
      _spurious_tags = @tag_class.find_or_create_by_path %w[D E]
      assert_equal [a, b], @tag_class.with_descendant(c).to_a
    end

    define_method 'test_with_descendant limits subsequent where clauses' do
      ac1 = @tag_class.create(name: 'A')
      ac2 = @tag_class.create(name: 'A')

      c1 = @tag_class.find_or_create_by_path %w[B C1]
      ac1.children << c1.parent

      c2 = @tag_class.find_or_create_by_path %w[B C2]
      ac2.children << c2.parent

      refute_equal ac2, ac1
      assert_equal [ac1, ac2].sort, @tag_class.where(name: 'A').to_a.sort
      assert_equal [ac1], @tag_class.with_descendant(c1).where(name: 'A').to_a
    end

    define_method 'test_lowest_common_ancestor finds parent for siblings' do
      t1 = @tag_class.create!(name: 't1')
      t11 = @tag_class.create!(name: 't11', parent: t1)
      t111 = @tag_class.create!(name: 't111', parent: t11)
      t112 = @tag_class.create!(name: 't112', parent: t11)
      t12 = @tag_class.create!(name: 't12', parent: t1)

      assert_equal t11, @tag_class.lowest_common_ancestor(t112, t111)
      assert_equal t1, @tag_class.lowest_common_ancestor(t12, t11)
      assert_equal t11, @tag_class.lowest_common_ancestor([t112, t111])
      assert_equal t1, @tag_class.lowest_common_ancestor([t12, t11])
      assert_equal t11, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t112 t111]))
      assert_equal t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t12 t11]))
    end

    define_method 'test_lowest_common_ancestor finds grandparent for cousins' do
      t1 = @tag_class.create!(name: 't1')
      t11 = @tag_class.create!(name: 't11', parent: t1)
      t111 = @tag_class.create!(name: 't111', parent: t11)
      t112 = @tag_class.create!(name: 't112', parent: t11)
      t12 = @tag_class.create!(name: 't12', parent: t1)
      t121 = @tag_class.create!(name: 't121', parent: t12)

      assert_equal t1, @tag_class.lowest_common_ancestor(t112, t111, t121)
      assert_equal t1, @tag_class.lowest_common_ancestor([t112, t111, t121])
      assert_equal t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t112 t111 t121]))
    end

    define_method 'test_lowest_common_ancestor for aunt-uncle/niece-nephew' do
      t1 = @tag_class.create!(name: 't1')
      t11 = @tag_class.create!(name: 't11', parent: t1)
      t112 = @tag_class.create!(name: 't112', parent: t11)
      t12 = @tag_class.create!(name: 't12', parent: t1)

      assert_equal t1, @tag_class.lowest_common_ancestor(t12, t112)
      assert_equal t1, @tag_class.lowest_common_ancestor([t12, t112])
      assert_equal t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t12 t112]))
    end

    define_method 'test_lowest_common_ancestor for parent/child' do
      t1 = @tag_class.create!(name: 't1')
      t12 = @tag_class.create!(name: 't12', parent: t1)
      t121 = @tag_class.create!(name: 't121', parent: t12)

      assert_equal t12, @tag_class.lowest_common_ancestor(t12, t121)
      assert_equal t1, @tag_class.lowest_common_ancestor(t1, t12)
      assert_equal t12, @tag_class.lowest_common_ancestor([t12, t121])
      assert_equal t1, @tag_class.lowest_common_ancestor([t1, t12])
      assert_equal t12, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t12 t121]))
      assert_equal t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t1 t12]))
    end

    define_method 'test_lowest_common_ancestor for grandparent/grandchild' do
      t1 = @tag_class.create!(name: 't1')
      t11 = @tag_class.create!(name: 't11', parent: t1)
      t111 = @tag_class.create!(name: 't111', parent: t11)
      t2 = @tag_class.create!(name: 't2')
      t21 = @tag_class.create!(name: 't21', parent: t2)
      t211 = @tag_class.create!(name: 't211', parent: t21)

      assert_equal t2, @tag_class.lowest_common_ancestor(t211, t2)
      assert_equal t1, @tag_class.lowest_common_ancestor(t111, t1)
      assert_equal t2, @tag_class.lowest_common_ancestor([t211, t2])
      assert_equal t1, @tag_class.lowest_common_ancestor([t111, t1])
      assert_equal t2, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t211 t2]))
      assert_equal t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t111 t1]))
    end

    define_method 'test_lowest_common_ancestor for whole extended family' do
      t1 = @tag_class.create!(name: 't1')
      t11 = @tag_class.create!(name: 't11', parent: t1)
      t111 = @tag_class.create!(name: 't111', parent: t11)
      t112 = @tag_class.create!(name: 't112', parent: t11)
      t12 = @tag_class.create!(name: 't12', parent: t1)
      t121 = @tag_class.create!(name: 't121', parent: t12)
      t2 = @tag_class.create!(name: 't2')
      t21 = @tag_class.create!(name: 't21', parent: t2)
      t211 = @tag_class.create!(name: 't211', parent: t21)

      assert_equal t1, @tag_class.lowest_common_ancestor(t1, t11, t111, t112, t12, t121)
      assert_equal t2, @tag_class.lowest_common_ancestor(t2, t21, t211)
      assert_equal t1, @tag_class.lowest_common_ancestor([t1, t11, t111, t112, t12, t121])
      assert_equal t2, @tag_class.lowest_common_ancestor([t2, t21, t211])
      assert_equal t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t1 t11 t111 t112 t12 t121]))
      assert_equal t2, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t2 t21 t211]))
    end

    define_method 'test_lowest_common_ancestor is nil for no items' do
      assert_nil @tag_class.lowest_common_ancestor
      assert_nil @tag_class.lowest_common_ancestor([])
      assert_nil @tag_class.lowest_common_ancestor(@tag_class.none)
    end

    define_method 'test_lowest_common_ancestor is nil for no common ancestors' do
      t1 = @tag_class.create!(name: 't1')
      t11 = @tag_class.create!(name: 't11', parent: t1)
      t111 = @tag_class.create!(name: 't111', parent: t11)
      t2 = @tag_class.create!(name: 't2')
      t21 = @tag_class.create!(name: 't21', parent: t2)
      t211 = @tag_class.create!(name: 't211', parent: t21)

      assert_nil @tag_class.lowest_common_ancestor(t111, t211)
      assert_nil @tag_class.lowest_common_ancestor([t111, t211])
      assert_nil @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t111 t211]))
    end

    define_method 'test_lowest_common_ancestor is itself for single item' do
      t1 = @tag_class.create!(name: 't1')
      t11 = @tag_class.create!(name: 't11', parent: t1)
      t111 = @tag_class.create!(name: 't111', parent: t11)
      t2 = @tag_class.create!(name: 't2')

      assert_equal t111, @tag_class.lowest_common_ancestor(t111)
      assert_equal t2, @tag_class.lowest_common_ancestor(t2)
      assert_equal t111, @tag_class.lowest_common_ancestor([t111])
      assert_equal t2, @tag_class.lowest_common_ancestor([t2])
      assert_equal t111, @tag_class.lowest_common_ancestor(@tag_class.where(name: 't111'))
      assert_equal t2, @tag_class.lowest_common_ancestor(@tag_class.where(name: 't2'))
    end

    define_method 'test_builds ancestry path' do
      child = @tag_class.find_or_create_by_path([
                                                  { name: 'grandparent', title: 'Nonnie' },
                                                  { name: 'parent', title: 'Mom' },
                                                  { name: 'child', title: 'Kid' }
                                                ])
      parent = child.parent
      parent.parent

      assert_equal %w[grandparent parent child], child.ancestry_path
      assert_equal %w[grandparent parent child], child.ancestry_path(:name)
      assert_equal %w[Nonnie Mom Kid], child.ancestry_path(:title)
    end

    define_method 'test_assembles ancestors' do
      child = @tag_class.find_or_create_by_path([
                                                  { name: 'grandparent', title: 'Nonnie' },
                                                  { name: 'parent', title: 'Mom' },
                                                  { name: 'child', title: 'Kid' }
                                                ])
      parent = child.parent
      grandparent = parent.parent

      assert_equal [parent, grandparent], child.ancestors
      assert_equal [child, parent, grandparent], child.self_and_ancestors
    end

    define_method 'test_finds by path' do
      child = @tag_class.find_or_create_by_path([
                                                  { name: 'grandparent', title: 'Nonnie' },
                                                  { name: 'parent', title: 'Mom' },
                                                  { name: 'child', title: 'Kid' }
                                                ])
      parent = child.parent
      grandparent = parent.parent

      assert_equal child, @tag_class.find_by_path(%w[grandparent parent child])
      assert_equal child, parent.find_by_path(%w[child])
      assert_equal child, grandparent.find_by_path(%w[parent child])
      assert_nil parent.find_by_path(%w[child larvae])
    end

    define_method 'test_respects attribute hashes with both selection and creation' do
      grandparent = @tag_class.find_or_create_by_path([
                                                        { name: 'grandparent', title: 'Nonnie' }
                                                      ])

      expected_title = 'something else'
      attrs = { title: expected_title }
      existing_title = grandparent.title
      new_grandparent = @tag_class.find_or_create_by_path(%w[grandparent], attrs)
      refute_equal grandparent, new_grandparent
      assert_equal expected_title, new_grandparent.title
      assert_equal existing_title, grandparent.reload.title
    end

    define_method 'test_creates hierarchy with given attribute' do
      expected_title = 'unicorn rainbows'
      attrs = { title: expected_title }
      child = @tag_class.find_or_create_by_path(%w[grandparent parent child], attrs)

      [child, child.parent, child.parent.parent].each do |ea|
        assert_equal expected_title, ea.title
      end
    end

    define_method 'test_finds correctly rooted paths' do
      _decoy = @tag_class.find_or_create_by_path %w[a b c d]
      b_d = @tag_class.find_or_create_by_path %w[b c d]
      assert_equal b_d, @tag_class.find_by_path(%w[b c d])
      assert_nil @tag_class.find_by_path(%w[c d])
    end

    define_method 'test_find_by_path for 1 node' do
      b = @tag_class.find_or_create_by_path %w[a b]
      b2 = b.root.find_by_path(%w[b])
      assert_equal b, b2
    end

    define_method 'test_find_by_path for 2 nodes' do
      path = %w[a b c]
      c = @tag_class.find_or_create_by_path path
      permutations = path.permutation.to_a
      correct = %w[b c]
      assert_equal c, c.root.find_by_path(correct)
      (permutations - correct).each do |bad_path|
        assert_nil c.root.find_by_path(bad_path)
      end
    end

    define_method 'test_find_by_path for 3 nodes' do
      d = @tag_class.find_or_create_by_path %w[a b c d]
      assert_equal d, d.root.find_by_path(%w[b c d])
      assert_equal d, @tag_class.find_by_path(%w[a b c d])
      assert_nil @tag_class.find_by_path(%w[d])
    end

    define_method 'test_returns nil for missing nodes' do
      assert_nil @tag_class.find_by_path(%w[missing])
      assert_nil @tag_class.find_by_path(%w[grandparent missing])
      assert_nil @tag_class.find_by_path(%w[grandparent parent missing])
      assert_nil @tag_class.find_by_path(%w[grandparent parent missing child])
    end

    define_method 'test_find_or_create_by_path uses existing records' do
      grandparent = @tag_class.find_or_create_by_path(%w[grandparent])
      assert_equal grandparent, grandparent
      child = @tag_class.find_or_create_by_path(%w[grandparent parent child])
      assert_equal child, child
    end

    define_method 'test_find_or_create_by_path creates 2-deep trees with strings' do
      subject = @tag_class.find_or_create_by_path(%w[events anniversary])
      assert_equal %w[events anniversary], subject.ancestry_path
    end

    define_method 'test_find_or_create_by_path creates 2-deep trees with hashes' do
      subject = @tag_class.find_or_create_by_path([
                                                    { name: 'test1', title: 'TEST1' },
                                                    { name: 'test2', title: 'TEST2' }
                                                  ])
      assert_equal %w[test1 test2], subject.ancestry_path
      assert_equal %w[TEST2 TEST1], subject.self_and_ancestors.map(&:title)
    end

    define_method 'test_hash_tree returns {} for depth 0' do
      @tag_class.find_or_create_by_path %w[a b c1 d1]
      assert_equal({}, @tag_class.hash_tree(limit_depth: 0))
    end

    define_method 'test_hash_tree limit_depth 1' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      a = d1.root
      a2 = @tag_class.create(name: 'a2')
      a3 = @tag_class.find_or_create_by_path(%w[a3 b3 c3]).root

      one_tree = { a => {}, a2 => {}, a3 => {} }
      assert_equal one_tree, @tag_class.hash_tree(limit_depth: 1)
    end

    define_method 'test_hash_tree limit_depth 2' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      a2 = @tag_class.create(name: 'a2')
      b2 = @tag_class.find_or_create_by_path %w[a b2]
      c3 = @tag_class.find_or_create_by_path %w[a3 b3 c3]
      b3 = c3.parent
      a3 = b3.parent

      two_tree = {
        a => { b => {}, b2 => {} },
        a2 => {},
        a3 => { b3 => {} }
      }
      assert_equal two_tree, @tag_class.hash_tree(limit_depth: 2)
    end

    define_method 'test_hash_tree limit_depth 3' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      a2 = @tag_class.create(name: 'a2')
      b2 = @tag_class.find_or_create_by_path %w[a b2]
      c3 = @tag_class.find_or_create_by_path %w[a3 b3 c3]
      b3 = c3.parent
      a3 = b3.parent

      three_tree = {
        a => { b => { c1 => {} }, b2 => {} },
        a2 => {},
        a3 => { b3 => { c3 => {} } }
      }
      assert_equal three_tree, @tag_class.hash_tree(limit_depth: 3)
    end

    define_method 'test_hash_tree limit_depth 4' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      a2 = @tag_class.create(name: 'a2')
      b2 = @tag_class.find_or_create_by_path %w[a b2]
      c3 = @tag_class.find_or_create_by_path %w[a3 b3 c3]
      b3 = c3.parent
      a3 = b3.parent

      full_tree = {
        a => { b => { c1 => { d1 => {} } }, b2 => {} },
        a2 => {},
        a3 => { b3 => { c3 => {} } }
      }
      assert_equal full_tree, @tag_class.hash_tree(limit_depth: 4)
    end

    define_method 'test_hash_tree no limit' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      a2 = @tag_class.create(name: 'a2')
      b2 = @tag_class.find_or_create_by_path %w[a b2]
      c3 = @tag_class.find_or_create_by_path %w[a3 b3 c3]
      b3 = c3.parent
      a3 = b3.parent

      full_tree = {
        a => { b => { c1 => { d1 => {} } }, b2 => {} },
        a2 => {},
        a3 => { b3 => { c3 => {} } }
      }
      assert_equal full_tree, @tag_class.hash_tree
    end

    define_method 'test_instance hash_tree returns {} for depth 0' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      b = d1.parent.parent
      assert_equal({}, b.hash_tree(limit_depth: 0))
    end

    define_method 'test_instance hash_tree limit_depth 1' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      b2 = @tag_class.find_or_create_by_path %w[a b2]

      two_tree = { a => { b => {}, b2 => {} } }
      assert_equal two_tree[a].slice(b), b.hash_tree(limit_depth: 1)
    end

    define_method 'test_instance hash_tree no limit from subroot' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      b2 = @tag_class.find_or_create_by_path %w[a b2]

      full_tree = { a => { b => { c1 => { d1 => {} } }, b2 => {} } }
      assert_equal full_tree[a].slice(b), b.hash_tree
    end

    define_method 'test_hash_tree from chained associations' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      b2 = @tag_class.find_or_create_by_path %w[a b2]

      full_tree = { a => { b => { c1 => { d1 => {} } }, b2 => {} } }
      assert_equal full_tree[a], a.children.hash_tree
    end

    define_method 'test_finds_by_path for very deep trees' do
      path = (1..20).to_a.map(&:to_s)
      subject = @tag_class.find_or_create_by_path(path)
      assert_equal path, subject.ancestry_path
      assert_equal subject, @tag_class.find_by_path(path)
      root = subject.root
      assert_equal subject, root.find_by_path(path[1..])
    end

    define_method 'test_DOT rendering for empty scope' do
      assert_equal "digraph G {\n}\n", @tag_class.to_dot_digraph(@tag_class.where('0=1'))
    end

    define_method 'test_DOT rendering for tree' do
      @tag_class.find_or_create_by_path(%w[a b1 c1])
      @tag_class.find_or_create_by_path(%w[a b2 c2])
      @tag_class.find_or_create_by_path(%w[a b2 c3])
      a, b1, b2, c1, c2, c3 = %w[a b1 b2 c1 c2 c3].map { |ea| @tag_class.where(name: ea).first.id }
      dot = @tag_class.roots.first.to_dot_digraph

      graph = <<~DOT
        digraph G {
          "#{a}" [label="a"]
          "#{a}" -> "#{b1}"
          "#{b1}" [label="b1"]
          "#{a}" -> "#{b2}"
          "#{b2}" [label="b2"]
          "#{b1}" -> "#{c1}"
          "#{c1}" [label="c1"]
          "#{b2}" -> "#{c2}"
          "#{c2}" [label="c2"]
          "#{b2}" -> "#{c3}"
          "#{c3}" [label="c3"]
        }
      DOT

      assert_equal(graph, dot)
    end

    define_method 'test_depth returns 0 for root' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      a = b.parent
      a2 = @tag_class.create(name: 'a2')
      c3 = @tag_class.find_or_create_by_path %w[a3 b3 c3]
      a3 = c3.parent.parent

      assert_equal 0, a.depth
      assert_equal 0, a2.depth
      assert_equal 0, a3.depth
    end

    define_method 'test_depth returns correct depth for nodes' do
      d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
      c1 = d1.parent
      b = c1.parent
      b2 = @tag_class.find_or_create_by_path %w[a b2]
      c3 = @tag_class.find_or_create_by_path %w[a3 b3 c3]
      b3 = c3.parent

      assert_equal 1, b.depth
      assert_equal 2, c1.depth
      assert_equal 3, d1.depth
      assert_equal 1, b2.depth
      assert_equal 1, b3.depth
      assert_equal 2, c3.depth
    end
  end
end

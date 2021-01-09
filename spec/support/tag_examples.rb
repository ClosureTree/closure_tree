require 'spec_helper'

RSpec.shared_examples_for Tag do

  let (:tag_class) { described_class }
  let (:tag_hierarchy_class) { described_class.hierarchy_class }

  context 'class setup' do

    it 'has correct accessible_attributes' do
      if tag_class._ct.use_attr_accessible?
        expect(tag_class.accessible_attributes.to_a).to match_array(%w(parent name title))
      end
    end

    it 'should build hierarchy classname correctly' do
      expect(tag_class.hierarchy_class).to eq(tag_hierarchy_class)
      expect(tag_class._ct.hierarchy_class_name).to eq(tag_hierarchy_class.to_s)
      expect(tag_class._ct.short_hierarchy_class_name).to eq(tag_hierarchy_class.to_s)
    end

    it 'should have a correct parent column name' do
      expected_parent_column_name = tag_class == UUIDTag ? 'parent_uuid' : 'parent_id'
      expect(tag_class._ct.parent_column_name).to eq(expected_parent_column_name)
    end
  end

  describe 'from empty db' do

    context 'with no tags' do
      it 'should return no entities' do
        expect(tag_class.roots).to be_empty
        expect(tag_class.leaves).to be_empty
      end

      it '#find_or_create_by_path with strings' do
        a = tag_class.create!(name: 'a')
        expect(a.find_or_create_by_path(%w{b c}).ancestry_path).to eq(%w{a b c})
      end

      it '#find_or_create_by_path with hashes' do
        a = tag_class.create!(name: 'a', title: 'A')
        subject = a.find_or_create_by_path([
          {name: 'b', title: 'B'},
          {name: 'c', title: 'C'}
        ])
        expect(subject.ancestry_path).to eq(%w{a b c})
        expect(subject.self_and_ancestors.map(&:title)).to eq(%w{C B A})
      end
    end

    context 'with 1 tag' do
      before do
        @tag = tag_class.create!(name: 'tag')
      end

      it 'should be a leaf' do
        expect(@tag.leaf?).to be_truthy
      end

      it 'should be a root' do
        expect(@tag.root?).to be_truthy
      end

      it 'has no parent' do
        expect(@tag.parent).to be_nil
      end

      it 'should return the only entity as a root and leaf' do
        expect(tag_class.all).to eq([@tag])
        expect(tag_class.roots).to eq([@tag])
        expect(tag_class.leaves).to eq([@tag])
      end

      it 'should not be found by passing find_by_path an array of blank strings' do
        expect(tag_class.find_by_path([''])).to be_nil
      end

      it 'should not be found by passing find_by_path an empty array' do
        expect(tag_class.find_by_path([])).to be_nil
      end

      it 'should not be found by passing find_by_path nil' do
        expect(tag_class.find_by_path(nil)).to be_nil
      end

      it 'should not be found by passing find_by_path an empty string' do
        expect(tag_class.find_by_path('')).to be_nil
      end

      it 'should not be found by passing find_by_path an array of nils' do
        expect(tag_class.find_by_path([nil])).to be_nil
      end

      it 'should not be found by passing find_by_path an array with an additional blank string' do
        expect(tag_class.find_by_path([@tag.name, ''])).to be_nil
      end

      it 'should not be found by passing find_by_path an array with an additional nil' do
        expect(tag_class.find_by_path([@tag.name, nil])).to be_nil
      end

      it 'should be found by passing find_by_path an array with its name' do
        expect(tag_class.find_by_path([@tag.name])).to eq @tag
      end

      it 'should be found by passing find_by_path its name' do
        expect(tag_class.find_by_path(@tag.name)).to eq @tag
      end

      context 'with child' do
        before do
          @child = tag_class.create!(name: 'tag 2')
        end

        def assert_roots_and_leaves
          expect(@tag.root?).to be_truthy
          expect(@tag.leaf?).to be_falsey

          expect(@child.root?).to be_falsey
          expect(@child.leaf?).to be_truthy
        end

        def assert_parent_and_children
          expect(@child.reload.parent).to eq(@tag)
          expect(@tag.reload.children.to_a).to eq([@child])
        end

        it 'adds children through add_child' do
          @tag.add_child @child
          assert_roots_and_leaves
          assert_parent_and_children
        end

        it 'adds children through collection' do
          @tag.children << @child
          assert_roots_and_leaves
          assert_parent_and_children
        end
      end
    end

    context 'with 2 tags' do
      before :each do
        @root = tag_class.create!(name: 'root')
        @leaf = @root.add_child(tag_class.create!(name: 'leaf'))
      end
      it 'should return a simple root and leaf' do
        expect(tag_class.roots).to eq([@root])
        expect(tag_class.leaves).to eq([@leaf])
      end
      it 'should return child_ids for root' do
        expect(@root.child_ids).to eq([@leaf.id])
      end

      it 'should return an empty array for leaves' do
        expect(@leaf.child_ids).to be_empty
      end
    end

    context '3 tag collection.create db' do
      before :each do
        @root = tag_class.create! name: 'root'
        @mid = @root.children.create! name: 'mid'
        @leaf = @mid.children.create! name: 'leaf'
        DestroyedTag.delete_all
      end

      it 'should create all tags' do
        expect(tag_class.all.to_a).to match_array([@root, @mid, @leaf])
      end

      it 'should return a root and leaf without middle tag' do
        expect(tag_class.roots).to eq([@root])
        expect(tag_class.leaves).to eq([@leaf])
      end

      it 'should delete leaves' do
        tag_class.leaves.destroy_all
        expect(tag_class.roots).to eq([@root]) # untouched
        expect(tag_class.leaves).to eq([@mid])
      end

      it 'should delete everything if you delete the roots' do
        tag_class.roots.destroy_all
        expect(tag_class.all).to be_empty
        expect(tag_class.roots).to be_empty
        expect(tag_class.leaves).to be_empty
        expect(DestroyedTag.all.map { |t| t.name }).to match_array(%w{root mid leaf})
      end

      it 'fix self_and_ancestors properly on reparenting' do
        t = tag_class.create! name: 'moar leaf'
        expect(t.self_and_ancestors.to_a).to eq([t])
        @mid.children << t
        expect(t.self_and_ancestors.to_a).to eq([t, @mid, @root])
      end

      it 'prevents ancestor loops' do
        @leaf.add_child @root
        expect(@root).not_to be_valid
        expect(@root.reload.descendants).to include(@leaf)
      end

      it 'moves non-leaves' do
        new_root = tag_class.create! name: 'new_root'
        new_root.children << @mid
        expect(@root.reload.descendants).to be_empty
        expect(new_root.descendants).to eq([@mid, @leaf])
        expect(@leaf.reload.ancestry_path).to eq(%w{new_root mid leaf})
      end

      it 'moves leaves' do
        new_root = tag_class.create! name: 'new_root'
        new_root.children << @leaf
        expect(new_root.descendants).to eq([@leaf])
        expect(@root.reload.descendants).to eq([@mid])
        expect(@leaf.reload.ancestry_path).to eq(%w{new_root leaf})
      end
    end

    context '3 tag explicit_create db' do
      before :each do
        @root = tag_class.create!(name: 'root')
        @mid = @root.add_child(tag_class.create!(name: 'mid'))
        @leaf = @mid.add_child(tag_class.create!(name: 'leaf'))
      end

      it 'should create all tags' do
        expect(tag_class.all.to_a).to match_array([@root, @mid, @leaf])
      end

      it 'should return a root and leaf without middle tag' do
        expect(tag_class.roots).to eq([@root])
        expect(tag_class.leaves).to eq([@leaf])
      end

      it 'should prevent parental loops from torso' do
        @mid.children << @root
        expect(@root.valid?).to be_falsey
        expect(@mid.reload.children).to eq([@leaf])
      end

      it 'should prevent parental loops from toes' do
        @leaf.children << @root
        expect(@root.valid?).to be_falsey
        expect(@leaf.reload.children).to be_empty
      end

      it 'should support re-parenting' do
        @root.children << @leaf
        expect(tag_class.leaves).to eq([@leaf, @mid])
      end

      it 'cleans up hierarchy references for leaves' do
        @leaf.destroy
        expect(tag_hierarchy_class.where(ancestor_id: @leaf.id)).to be_empty
        expect(tag_hierarchy_class.where(descendant_id: @leaf.id)).to be_empty
      end

      it 'cleans up hierarchy references' do
        @mid.destroy
        expect(tag_hierarchy_class.where(ancestor_id: @mid.id)).to be_empty
        expect(tag_hierarchy_class.where(descendant_id: @mid.id)).to be_empty
        expect(@root.reload).to be_root
        root_hiers = @root.ancestor_hierarchies.to_a
        expect(root_hiers.size).to eq(1)
        expect(tag_hierarchy_class.where(ancestor_id: @root.id)).to eq(root_hiers)
        expect(tag_hierarchy_class.where(descendant_id: @root.id)).to eq(root_hiers)
      end

      it 'should have different hash codes for each hierarchy model' do
        hashes = tag_hierarchy_class.all.map(&:hash)
        expect(hashes).to match_array(hashes.uniq)
      end

      it 'should return the same hash code for equal hierarchy models' do
        expect(tag_hierarchy_class.first.hash).to eq(tag_hierarchy_class.first.hash)
      end
    end

    it 'performs as the readme says it does' do
      grandparent = tag_class.create(name: 'Grandparent')
      parent = grandparent.children.create(name: 'Parent')
      child1 = tag_class.create(name: 'First Child', parent: parent)
      child2 = tag_class.new(name: 'Second Child')
      parent.children << child2
      child3 = tag_class.new(name: 'Third Child')
      parent.add_child child3
      expect(grandparent.self_and_descendants.collect(&:name)).to eq(
        ['Grandparent', 'Parent', 'First Child', 'Second Child', 'Third Child']
      )
      expect(child1.ancestry_path).to eq(
        ['Grandparent', 'Parent', 'First Child']
      )
      expect(child3.ancestry_path).to eq(
        ['Grandparent', 'Parent', 'Third Child']
      )
      d = tag_class.find_or_create_by_path %w(a b c d)
      h = tag_class.find_or_create_by_path %w(e f g h)
      e = h.root
      d.add_child(e) # "d.children << e" would work too, of course
      expect(h.ancestry_path).to eq(%w(a b c d e f g h))
    end

    it 'roots sort alphabetically' do
      expected = ('a'..'z').to_a
      expected.shuffle.each { |ea| tag_class.create!(name: ea) }
      expect(tag_class.roots.collect { |ea| ea.name }).to eq(expected)
    end

    context 'with simple tree' do
      before :each do
        tag_class.find_or_create_by_path %w(a1 b1 c1a)
        tag_class.find_or_create_by_path %w(a1 b1 c1b)
        tag_class.find_or_create_by_path %w(a1 b1 c1c)
        tag_class.find_or_create_by_path %w(a1 b1b)
        tag_class.find_or_create_by_path %w(a2 b2)
        tag_class.find_or_create_by_path %w(a3)

        @a1, @a2, @a3, @b1, @b1b, @b2, @c1a, @c1b, @c1c =
          tag_class.all.sort_by(&:name)
        @expected_roots = [@a1, @a2, @a3]
        @expected_leaves = [@c1a, @c1b, @c1c, @b1b, @b2, @a3]
        @expected_siblings = [[@a1, @a2, @a3], [@b1, @b1b], [@c1a, @c1b, @c1c]]
        @expected_only_children = tag_class.all - @expected_siblings.flatten
      end

      it 'should find global roots' do
        expect(tag_class.roots.to_a).to match_array(@expected_roots)
      end
      it 'should return root? for roots' do
        @expected_roots.each { |ea| expect(ea).to be_root }
      end
      it 'should not return root? for non-roots' do
        [@b1, @b2, @c1a, @c1b].each { |ea| expect(ea).not_to be_root }
      end
      it 'should return the correct root' do
        {@a1 => @a1, @a2 => @a2, @a3 => @a3,
          @b1 => @a1, @b2 => @a2, @c1a => @a1, @c1b => @a1}.each do |node, root|
          expect(node.root).to eq(root)
        end
      end
      it 'should assemble global leaves' do
        expect(tag_class.leaves.to_a).to match_array(@expected_leaves)
      end
      it 'assembles siblings properly' do
        @expected_siblings.each do |siblings|
          siblings.each do |ea|
            expect(ea.self_and_siblings.to_a).to match_array(siblings)
            expect(ea.siblings.to_a).to match_array(siblings - [ea])
          end
        end
        @expected_only_children.each do |ea|
          expect(ea.siblings).to eq([])
        end
      end
      it 'assembles before_siblings' do
        @expected_siblings.each do |siblings|
          (siblings.size - 1).times do |i|
            target = siblings[i]
            expected_before = siblings.first(i)
            expect(target.siblings_before.to_a).to eq(expected_before)
          end
        end
      end
      it 'assembles after_siblings' do
        @expected_siblings.each do |siblings|
          (siblings.size - 1).times do |i|
            target = siblings[i]
            expected_after = siblings.last(siblings.size - 1 - i)
            expect(target.siblings_after.to_a).to eq(expected_after)
          end
        end
      end
      it 'should assemble instance leaves' do
        {@a1 => [@b1b, @c1a, @c1b, @c1c], @b1 => [@c1a, @c1b, @c1c], @a2 => [@b2]}.each do |node, leaves|
          expect(node.leaves.to_a).to eq(leaves)
        end
        @expected_leaves.each { |ea| expect(ea.leaves.to_a).to eq([ea]) }
      end
      it 'should return leaf? for leaves' do
        @expected_leaves.each { |ea| expect(ea).to be_leaf }
      end

      it 'can move roots' do
        @c1a.children << @a2
        @b2.reload.children << @a3
        expect(@a3.reload.ancestry_path).to eq(%w(a1 b1 c1a a2 b2 a3))
      end

      it 'cascade-deletes from roots' do
        victim_names = @a1.self_and_descendants.map(&:name)
        survivor_names = tag_class.all.map(&:name) - victim_names
        @a1.destroy
        expect(tag_class.all.map(&:name)).to eq(survivor_names)
      end
    end

    context 'with_ancestor' do
      it 'works with no rows' do
        expect(tag_class.with_ancestor.to_a).to be_empty
      end
      it 'finds only children' do
        c = tag_class.find_or_create_by_path %w(A B C)
        a, b = c.parent.parent, c.parent
        spurious_tags = tag_class.find_or_create_by_path %w(D E)
        expect(tag_class.with_ancestor(a).to_a).to eq([b, c])
      end
      it 'limits subsequent where clauses' do
        a1c = tag_class.find_or_create_by_path %w(A1 B C)
        a2c = tag_class.find_or_create_by_path %w(A2 B C)
        # different paths!
        expect(a1c).not_to eq(a2c)
        expect(tag_class.where(:name => 'C').to_a).to match_array([a1c, a2c])
        expect(tag_class.with_ancestor(a1c.parent.parent).where(:name => 'C').to_a).to eq([a1c])
      end
    end

    context 'with_descendant' do
      it 'works with no rows' do
        expect(tag_class.with_descendant.to_a).to be_empty
      end

      it 'finds only parents' do
        c = tag_class.find_or_create_by_path %w(A B C)
        a, b = c.parent.parent, c.parent
        spurious_tags = tag_class.find_or_create_by_path %w(D E)
        expect(tag_class.with_descendant(c).to_a).to eq([a, b])
      end

      it 'limits subsequent where clauses' do
        ac1 = tag_class.create(name: 'A')
        ac2 = tag_class.create(name: 'A')

        c1 = tag_class.find_or_create_by_path %w(B C1)
        ac1.children << c1.parent

        c2 = tag_class.find_or_create_by_path %w(B C2)
        ac2.children << c2.parent

        # different paths!
        expect(ac1).not_to eq(ac2)
        expect(tag_class.where(:name => 'A').to_a).to match_array([ac1, ac2])
        expect(tag_class.with_descendant(c1).where(:name => 'A').to_a).to eq([ac1])
      end
    end

    context 'lowest_common_ancestor' do
      let!(:t1) { tag_class.create!(name: 't1') }
      let!(:t11) { tag_class.create!(name: 't11', parent: t1) }
      let!(:t111) { tag_class.create!(name: 't111', parent: t11) }
      let!(:t112) { tag_class.create!(name: 't112', parent: t11) }
      let!(:t12) { tag_class.create!(name: 't12', parent: t1) }
      let!(:t121) { tag_class.create!(name: 't121', parent: t12) }
      let!(:t2) { tag_class.create!(name: 't2') }
      let!(:t21) { tag_class.create!(name: 't21', parent: t2) }
      let!(:t211) { tag_class.create!(name: 't211', parent: t21) }

      it 'finds the parent for siblings' do
        expect(tag_class.lowest_common_ancestor(t112, t111)).to eq t11
        expect(tag_class.lowest_common_ancestor(t12, t11)).to eq t1

        expect(tag_class.lowest_common_ancestor([t112, t111])).to eq t11
        expect(tag_class.lowest_common_ancestor([t12, t11])).to eq t1

        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t112', 't111']))).to eq t11
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t12', 't11']))).to eq t1
      end

      it 'finds the grandparent for cousins' do
        expect(tag_class.lowest_common_ancestor(t112, t111, t121)).to eq t1
        expect(tag_class.lowest_common_ancestor([t112, t111, t121])).to eq t1
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t112', 't111', 't121']))).to eq t1
      end

      it 'finds the parent/grandparent for aunt-uncle/niece-nephew' do
        expect(tag_class.lowest_common_ancestor(t12, t112)).to eq t1
        expect(tag_class.lowest_common_ancestor([t12, t112])).to eq t1
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t12', 't112']))).to eq t1
      end

      it 'finds the self/parent for parent/child' do
        expect(tag_class.lowest_common_ancestor(t12, t121)).to eq t12
        expect(tag_class.lowest_common_ancestor(t1, t12)).to eq t1

        expect(tag_class.lowest_common_ancestor([t12, t121])).to eq t12
        expect(tag_class.lowest_common_ancestor([t1, t12])).to eq t1

        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t12', 't121']))).to eq t12
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t1', 't12']))).to eq t1
      end

      it 'finds the self/grandparent for grandparent/grandchild' do
        expect(tag_class.lowest_common_ancestor(t211, t2)).to eq t2
        expect(tag_class.lowest_common_ancestor(t111, t1)).to eq t1

        expect(tag_class.lowest_common_ancestor([t211, t2])).to eq t2
        expect(tag_class.lowest_common_ancestor([t111, t1])).to eq t1

        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t211', 't2']))).to eq t2
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t111', 't1']))).to eq t1
      end

      it 'finds the grandparent for a whole extended family' do
        expect(tag_class.lowest_common_ancestor(t1, t11, t111, t112, t12, t121)).to eq t1
        expect(tag_class.lowest_common_ancestor(t2, t21, t211)).to eq t2

        expect(tag_class.lowest_common_ancestor([t1, t11, t111, t112, t12, t121])).to eq t1
        expect(tag_class.lowest_common_ancestor([t2, t21, t211])).to eq t2

        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t1', 't11', 't111', 't112', 't12', 't121']))).to eq t1
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t2', 't21', 't211']))).to eq t2
      end

      it 'is nil for no items' do
        expect(tag_class.lowest_common_ancestor).to be_nil
        expect(tag_class.lowest_common_ancestor([])).to be_nil
        expect(tag_class.lowest_common_ancestor(tag_class.none)).to be_nil
      end

      it 'is nil if there are no common ancestors' do
        expect(tag_class.lowest_common_ancestor(t111, t211)).to be_nil
        expect(tag_class.lowest_common_ancestor([t111, t211])).to be_nil
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: ['t111', 't211']))).to be_nil
      end

      it 'is itself for single item' do
        expect(tag_class.lowest_common_ancestor(t111)).to eq t111
        expect(tag_class.lowest_common_ancestor(t2)).to eq t2

        expect(tag_class.lowest_common_ancestor([t111])).to eq t111
        expect(tag_class.lowest_common_ancestor([t2])).to eq t2

        expect(tag_class.lowest_common_ancestor(tag_class.where(name: 't111'))).to eq t111
        expect(tag_class.lowest_common_ancestor(tag_class.where(name: 't2'))).to eq t2
      end
    end

    context 'paths' do
      context 'with grandchild' do
        before do
          @child = tag_class.find_or_create_by_path([
            {name: 'grandparent', title: 'Nonnie'},
            {name: 'parent', title: 'Mom'},
            {name: 'child', title: 'Kid'}])
          @parent = @child.parent
          @grandparent = @parent.parent
        end

        it 'should build ancestry path' do
          expect(@child.ancestry_path).to eq(%w{grandparent parent child})
          expect(@child.ancestry_path(:name)).to eq(%w{grandparent parent child})
          expect(@child.ancestry_path(:title)).to eq(%w{Nonnie Mom Kid})
        end

        it 'assembles ancestors' do
          expect(@child.ancestors).to eq([@parent, @grandparent])
          expect(@child.self_and_ancestors).to eq([@child, @parent, @grandparent])
        end

        it 'should find by path' do
          # class method:
          expect(tag_class.find_by_path(%w{grandparent parent child})).to eq(@child)
          # instance method:
          expect(@parent.find_by_path(%w{child})).to eq(@child)
          expect(@grandparent.find_by_path(%w{parent child})).to eq(@child)
          expect(@parent.find_by_path(%w{child larvae})).to be_nil
        end

        it 'should respect attribute hashes with both selection and creation' do
          expected_title = 'something else'
          attrs = {title: expected_title}
          existing_title = @grandparent.title
          new_grandparent = tag_class.find_or_create_by_path(%w{grandparent}, attrs)
          expect(new_grandparent).not_to eq(@grandparent)
          expect(new_grandparent.title).to eq(expected_title)
          expect(@grandparent.reload.title).to eq(existing_title)
        end

        it 'should create a hierarchy with a given attribute' do
          expected_title = 'unicorn rainbows'
          attrs = {title: expected_title}
          child = tag_class.find_or_create_by_path(%w{grandparent parent child}, attrs)
          expect(child).not_to eq(@child)
          [child, child.parent, child.parent.parent].each do |ea|
            expect(ea.title).to eq(expected_title)
          end
        end
      end

      it 'finds correctly rooted paths' do
        decoy = tag_class.find_or_create_by_path %w(a b c d)
        b_d = tag_class.find_or_create_by_path %w(b c d)
        expect(tag_class.find_by_path(%w(b c d))).to eq(b_d)
        expect(tag_class.find_by_path(%w(c d))).to be_nil
      end

      it 'find_by_path for 1 node' do
        b = tag_class.find_or_create_by_path %w(a b)
        b2 = b.root.find_by_path(%w(b))
        expect(b2).to eq(b)
      end

      it 'find_by_path for 2 nodes' do
        path = %w(a b c)
        c = tag_class.find_or_create_by_path path
        permutations = path.permutation.to_a
        correct = %w(b c)
        expect(c.root.find_by_path(correct)).to eq(c)
        (permutations - correct).each do |bad_path|
          expect(c.root.find_by_path(bad_path)).to be_nil
        end
      end

      it 'find_by_path for 3 nodes' do
        d = tag_class.find_or_create_by_path %w(a b c d)
        expect(d.root.find_by_path(%w(b c d))).to eq(d)
        expect(tag_class.find_by_path(%w(a b c d))).to eq(d)
        expect(tag_class.find_by_path(%w(d))).to be_nil
      end

      it 'should return nil for missing nodes' do
        expect(tag_class.find_by_path(%w{missing})).to be_nil
        expect(tag_class.find_by_path(%w{grandparent missing})).to be_nil
        expect(tag_class.find_by_path(%w{grandparent parent missing})).to be_nil
        expect(tag_class.find_by_path(%w{grandparent parent missing child})).to be_nil
      end

      describe '.find_or_create_by_path' do
        it 'uses existing records' do
          grandparent = tag_class.find_or_create_by_path(%w{grandparent})
          expect(grandparent).to eq(grandparent)
          child = tag_class.find_or_create_by_path(%w{grandparent parent child})
          expect(child).to eq(child)
        end

        it 'creates 2-deep trees with strings' do
          subject = tag_class.find_or_create_by_path(%w{events anniversary})
          expect(subject.ancestry_path).to eq(%w{events anniversary})
        end

        it 'creates 2-deep trees with hashes' do
          subject = tag_class.find_or_create_by_path([
            {name: 'test1', title: 'TEST1'},
            {name: 'test2', title: 'TEST2'}
          ])
          expect(subject.ancestry_path).to eq(%w{test1 test2})
          # `self_and_ancestors` and `ancestors` is ordered parent-first. (!!)
          expect(subject.self_and_ancestors.map(&:title)).to eq(%w{TEST2 TEST1})
        end

      end
    end

    context 'hash_tree' do
      before :each do
        @d1 = tag_class.find_or_create_by_path %w(a b c1 d1)
        @c1 = @d1.parent
        @b = @c1.parent
        @a = @b.parent
        @a2 = tag_class.create(name: 'a2')
        @b2 = tag_class.find_or_create_by_path %w(a b2)
        @c3 = tag_class.find_or_create_by_path %w(a3 b3 c3)
        @b3 = @c3.parent
        @a3 = @b3.parent
        @tree2 = {
          @a => {@b => {}, @b2 => {}}, @a2 => {}, @a3 => {@b3 => {}}
        }

        @one_tree = {
          @a => {},
          @a2 => {},
          @a3 => {}
        }
        @two_tree = {
          @a => {
            @b => {},
            @b2 => {}
          },
          @a2 => {},
          @a3 => {
            @b3 => {}
          }
        }
        @three_tree = {
          @a => {
            @b => {
              @c1 => {},
            },
            @b2 => {}
          },
          @a2 => {},
          @a3 => {
            @b3 => {
              @c3 => {}
            }
          }
        }
        @full_tree = {
          @a => {
            @b => {
              @c1 => {
                @d1 => {}
              },
            },
            @b2 => {}
          },
          @a2 => {},
          @a3 => {
            @b3 => {
              @c3 => {}
            }
          }
        }
        #File.open("example.dot", "w") { |f| f.write(tag_class.root.to_dot_digraph) }
      end

      context '#hash_tree' do
        it 'returns {} for depth 0' do
          expect(tag_class.hash_tree(limit_depth: 0)).to eq({})
        end
        it 'limit_depth 1' do
          expect(tag_class.hash_tree(limit_depth: 1)).to eq(@one_tree)
        end
        it 'limit_depth 2' do
          expect(tag_class.hash_tree(limit_depth: 2)).to eq(@two_tree)
        end
        it 'limit_depth 3' do
          expect(tag_class.hash_tree(limit_depth: 3)).to eq(@three_tree)
        end
        it 'limit_depth 4' do
          expect(tag_class.hash_tree(limit_depth: 4)).to eq(@full_tree)
        end
        it 'no limit' do
          expect(tag_class.hash_tree).to eq(@full_tree)
        end
      end

      context '.hash_tree' do
        it 'returns {} for depth 0' do
          expect(@b.hash_tree(limit_depth: 0)).to eq({})
        end
        it 'limit_depth 1' do
          expect(@b.hash_tree(limit_depth: 1)).to eq(@two_tree[@a].slice(@b))
        end
        it 'limit_depth 2' do
          expect(@b.hash_tree(limit_depth: 2)).to eq(@three_tree[@a].slice(@b))
        end
        it 'limit_depth 3' do
          expect(@b.hash_tree(limit_depth: 3)).to eq(@full_tree[@a].slice(@b))
        end
        it 'no limit from subsubroot' do
          expect(@c1.hash_tree).to eq(@full_tree[@a][@b].slice(@c1))
        end
        it 'no limit from subroot' do
          expect(@b.hash_tree).to eq(@full_tree[@a].slice(@b))
        end
        it 'no limit from root' do
          expect(@a.hash_tree.merge(@a2.hash_tree)).to eq(@full_tree.slice(@a, @a2))
        end
      end

      context '.hash_tree from relations' do
        it 'limit_depth 2 from chained activerecord association subroots' do
          expect(@a.children.hash_tree(limit_depth: 2)).to eq(@three_tree[@a])
        end
        it 'no limit from chained activerecord association subroots' do
          expect(@a.children.hash_tree).to eq(@full_tree[@a])
        end
        it 'limit_depth 3 from b.parent' do
          expect(@b.parent.hash_tree(limit_depth: 3)).to eq(@three_tree.slice(@a))
        end
        it 'no limit_depth from b.parent' do
          expect(@b.parent.hash_tree).to eq(@full_tree.slice(@a))
        end
        it 'no limit_depth from c.parent' do
          expect(@c1.parent.hash_tree).to eq(@full_tree[@a].slice(@b))
        end
      end
    end

    it 'finds_by_path for very deep trees' do
      expect(tag_class._ct).to receive(:max_join_tables).at_least(1).and_return(3)
      path = (1..20).to_a.map { |ea| ea.to_s }
      subject = tag_class.find_or_create_by_path(path)
      expect(subject.ancestry_path).to eq(path)
      expect(tag_class.find_by_path(path)).to eq(subject)
      root = subject.root
      expect(root.find_by_path(path[1..-1])).to eq(subject)
    end

    describe 'DOT rendering' do
      it 'should render for an empty scope' do
        expect(tag_class.to_dot_digraph(tag_class.where('0=1'))).to eq("digraph G {\n}\n")
      end
      it 'should render for an empty scope' do
        tag_class.find_or_create_by_path(%w(a b1 c1))
        tag_class.find_or_create_by_path(%w(a b2 c2))
        tag_class.find_or_create_by_path(%w(a b2 c3))
        a, b1, b2, c1, c2, c3 = %w(a b1 b2 c1 c2 c3).map { |ea| tag_class.where(name: ea).first.id }
        dot = tag_class.roots.first.to_dot_digraph
        expect(dot).to eq <<-DOT
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
      end
    end
  end
end

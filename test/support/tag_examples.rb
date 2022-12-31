# frozen_string_literal: true

module TagExamples
  def self.included(mod)
    @@described_class = mod.name.safe_constantize
  end

  describe 'TagExamples' do
    before do
      @tag_class = @@described_class
      @tag_hierarchy_class = @@described_class.hierarchy_class
    end

    describe 'class setup' do
      it 'has correct accessible_attributes' do
        if @tag_class._ct.use_attr_accessible?
          assert_equal(%w[parent name title].sort, @tag_class.accessible_attributes.to_a.sort)
        end
      end

      it 'should build hierarchy classname correctly' do
        assert_equal @tag_hierarchy_class, @tag_class.hierarchy_class
        assert_equal @tag_hierarchy_class.to_s, @tag_class._ct.hierarchy_class_name
        assert_equal @tag_hierarchy_class.to_s, @tag_class._ct.short_hierarchy_class_name
      end

      it 'should have a correct parent column name' do
        expected_parent_column_name = @tag_class == UUIDTag ? 'parent_uuid' : 'parent_id'
        assert_equal expected_parent_column_name, @tag_class._ct.parent_column_name
      end
    end

    describe 'from empty db' do
      describe 'with no tags' do
        it 'should return no entities' do
          assert_empty @tag_class.roots
          assert_empty @tag_class.leaves
        end

        it '#find_or_create_by_path with strings' do
          a = @tag_class.create!(name: 'a')
          assert_equal(%w[a b c], a.find_or_create_by_path(%w[b c]).ancestry_path)
        end

        it '#find_or_create_by_path with hashes' do
          a = @tag_class.create!(name: 'a', title: 'A')
          subject = a.find_or_create_by_path([
                                               { name: 'b', title: 'B' },
                                               { name: 'c', title: 'C' }
                                             ])
          assert_equal(%w[a b c], subject.ancestry_path)
          assert_equal(%w[C B A], subject.self_and_ancestors.map(&:title))
        end
      end

      describe 'with 1 tag' do
        before do
          @tag = @tag_class.create!(name: 'tag')
        end

        it 'should be a leaf' do
          assert @tag.leaf?
        end

        it 'should be a root' do
          assert @tag.root?
        end

        it 'has no parent' do
          assert_nil @tag.parent
        end

        it 'should return the only entity as a root and leaf' do
          assert_equal [@tag], @tag_class.all
          assert_equal [@tag], @tag_class.roots
          assert_equal [@tag], @tag_class.leaves
        end

        it 'should not be found by passing find_by_path an array of blank strings' do
          assert_nil @tag_class.find_by_path([''])
        end

        it 'should not be found by passing find_by_path an empty array' do
          assert_nil @tag_class.find_by_path([])
        end

        it 'should not be found by passing find_by_path nil' do
          assert_nil @tag_class.find_by_path(nil)
        end

        it 'should not be found by passing find_by_path an empty string' do
          assert_nil @tag_class.find_by_path('')
        end

        it 'should not be found by passing find_by_path an array of nils' do
          assert_nil @tag_class.find_by_path([nil])
        end

        it 'should not be found by passing find_by_path an array with an additional blank string' do
          assert_nil @tag_class.find_by_path([@tag.name, ''])
        end

        it 'should not be found by passing find_by_path an array with an additional nil' do
          assert_nil @tag_class.find_by_path([@tag.name, nil])
        end

        it 'should be found by passing find_by_path an array with its name' do
          assert_equal @tag, @tag_class.find_by_path([@tag.name])
        end

        it 'should be found by passing find_by_path its name' do
          assert_equal @tag, @tag_class.find_by_path(@tag.name)
        end

        describe 'with child' do
          before do
            @child = @tag_class.create!(name: 'tag 2')
          end

          def assert_roots_and_leaves
            assert @tag.root?
            refute @tag.leaf?

            refute @child.root?
            assert @child.leaf?
          end

          def assert_parent_and_children
            assert_equal @tag, @child.reload.parent
            assert_equal [@child], @tag.reload.children.to_a
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

      describe 'with 2 tags' do
        before do
          @root = @tag_class.create!(name: 'root')
          @leaf = @root.add_child(@tag_class.create!(name: 'leaf'))
        end

        it 'should return a simple root and leaf' do
          assert_equal [@root], @tag_class.roots
          assert_equal [@leaf], @tag_class.leaves
        end

        it 'should return child_ids for root' do
          assert_equal [@leaf.id], @root.child_ids
        end

        it 'should return an empty array for leaves' do
          assert_empty @leaf.child_ids
        end
      end

      describe '3 tag collection.create db' do
        before do
          @root = @tag_class.create! name: 'root'
          @mid = @root.children.create! name: 'mid'
          @leaf = @mid.children.create! name: 'leaf'
          DestroyedTag.delete_all
        end

        it 'should create all tags' do
          assert_equal [@root, @mid, @leaf].sort, @tag_class.all.to_a.sort
        end

        it 'should return a root and leaf without middle tag' do
          assert_equal [@root], @tag_class.roots
          assert_equal [@leaf], @tag_class.leaves
        end

        it 'should delete leaves' do
          @tag_class.leaves.destroy_all
          assert_equal [@root], @tag_class.roots # untouched
          assert_equal [@mid], @tag_class.leaves
        end

        it 'should delete everything if you delete the roots' do
          @tag_class.roots.destroy_all
          assert_empty @tag_class.all
          assert_empty @tag_class.roots
          assert_empty @tag_class.leaves
          assert_equal %w[root mid leaf].sort, DestroyedTag.all.map(&:name).sort
        end

        it 'fix self_and_ancestors properly on reparenting' do
          t = @tag_class.create! name: 'moar leaf'
          assert_equal [t], t.self_and_ancestors.to_a
          @mid.children << t
          assert_equal [t, @mid, @root], t.self_and_ancestors.to_a
        end

        it 'prevents ancestor loops' do
          @leaf.add_child @root
          refute @root.valid?
          assert_includes @root.reload.descendants, @leaf
        end

        it 'moves non-leaves' do
          new_root = @tag_class.create! name: 'new_root'
          new_root.children << @mid
          assert_empty @root.reload.descendants
          assert_equal [@mid, @leaf], new_root.descendants
          assert_equal %w[new_root mid leaf], @leaf.reload.ancestry_path
        end

        it 'moves leaves' do
          new_root = @tag_class.create! name: 'new_root'
          new_root.children << @leaf
          assert_equal [@leaf], new_root.descendants
          assert_equal [@mid], @root.reload.descendants
          assert_equal %w[new_root leaf], @leaf.reload.ancestry_path
        end
      end

      describe '3 tag explicit_create db' do
        before do
          @root = @tag_class.create!(name: 'root')
          @mid = @root.add_child(@tag_class.create!(name: 'mid'))
          @leaf = @mid.add_child(@tag_class.create!(name: 'leaf'))
        end

        it 'should create all tags' do
          assert_equal [@root, @mid, @leaf].sort, @tag_class.all.to_a.sort
        end

        it 'should return a root and leaf without middle tag' do
          assert_equal [@root], @tag_class.roots
          assert_equal [@leaf], @tag_class.leaves
        end

        it 'should prevent parental loops from torso' do
          @mid.children << @root
          refute @root.valid?
          assert_equal [@leaf], @mid.reload.children
        end

        it 'should prevent parental loops from toes' do
          @leaf.children << @root
          refute @root.valid?
          assert_empty @leaf.reload.children
        end

        it 'should support re-parenting' do
          @root.children << @leaf
          assert_equal [@leaf, @mid], @tag_class.leaves
        end

        it 'cleans up hierarchy references for leaves' do
          @leaf.destroy
          assert_empty @tag_hierarchy_class.where(ancestor_id: @leaf.id)
          assert_empty @tag_hierarchy_class.where(descendant_id: @leaf.id)
        end

        it 'cleans up hierarchy references' do
          @mid.destroy
          assert_empty @tag_hierarchy_class.where(ancestor_id: @mid.id)
          assert_empty @tag_hierarchy_class.where(descendant_id: @mid.id)
          assert @root.reload.root?
          root_hiers = @root.ancestor_hierarchies.to_a
          assert_equal 1, root_hiers.size
          assert_equal root_hiers, @tag_hierarchy_class.where(ancestor_id: @root.id)
          assert_equal root_hiers, @tag_hierarchy_class.where(descendant_id: @root.id)
        end

        it 'should have different hash codes for each hierarchy model' do
          hashes = @tag_hierarchy_class.all.map(&:hash)
          assert_equal hashes.uniq.sort, hashes.sort
        end

        it 'should return the same hash code for equal hierarchy models' do
          assert_equal @tag_hierarchy_class.first.hash, @tag_hierarchy_class.first.hash
        end
      end

      it 'performs as the readme says it does' do
        grandparent = @tag_class.create(name: 'Grandparent')
        parent = grandparent.children.create(name: 'Parent')
        child1 = @tag_class.create(name: 'First Child', parent: parent)
        child2 = @tag_class.new(name: 'Second Child')
        parent.children << child2
        child3 = @tag_class.new(name: 'Third Child')
        parent.add_child child3
        assert_equal(
          ['Grandparent', 'Parent', 'First Child', 'Second Child', 'Third Child'],
          grandparent.self_and_descendants.collect(&:name)
        )
        assert_equal(['Grandparent', 'Parent', 'First Child'], child1.ancestry_path)
        assert_equal(['Grandparent', 'Parent', 'Third Child'], child3.ancestry_path)
        d = @tag_class.find_or_create_by_path %w[a b c d]
        h = @tag_class.find_or_create_by_path %w[e f g h]
        e = h.root
        d.add_child(e) # "d.children << e" would work too, of course
        assert_equal %w[a b c d e f g h], h.ancestry_path
      end

      it 'roots sort alphabetically' do
        expected = ('a'..'z').to_a
        expected.shuffle.each { |ea| @tag_class.create!(name: ea) }
        assert_equal expected, @tag_class.roots.collect(&:name)
      end

      describe 'with simple tree' do
        before do
          @tag_class.find_or_create_by_path %w[a1 b1 c1a]
          @tag_class.find_or_create_by_path %w[a1 b1 c1b]
          @tag_class.find_or_create_by_path %w[a1 b1 c1c]
          @tag_class.find_or_create_by_path %w[a1 b1b]
          @tag_class.find_or_create_by_path %w[a2 b2]
          @tag_class.find_or_create_by_path %w[a3]

          @a1, @a2, @a3, @b1, @b1b, @b2, @c1a, @c1b, @c1c = @tag_class.all.sort_by(&:name)
          @expected_roots = [@a1, @a2, @a3]
          @expected_leaves = [@c1a, @c1b, @c1c, @b1b, @b2, @a3]
          @expected_siblings = [[@a1, @a2, @a3], [@b1, @b1b], [@c1a, @c1b, @c1c]]
          @expected_only_children = @tag_class.all - @expected_siblings.flatten
        end

        it 'should find global roots' do
          assert_equal @expected_roots.sort, @tag_class.roots.to_a.sort
        end

        it 'should return root? for roots' do
          @expected_roots.each { |ea| assert(ea.root?) }
        end

        it 'should not return root? for non-roots' do
          [@b1, @b2, @c1a, @c1b].each { |ea| refute(ea.root?) }
        end

        it 'should return the correct root' do
          { @a1 => @a1, @a2 => @a2, @a3 => @a3,
            @b1 => @a1, @b2 => @a2, @c1a => @a1, @c1b => @a1 }.each do |node, root|
            assert_equal(root, node.root)
          end
        end

        it 'should assemble global leaves' do
          assert_equal @expected_leaves.sort, @tag_class.leaves.to_a.sort
        end

        it 'assembles siblings properly' do
          @expected_siblings.each do |siblings|
            siblings.each do |ea|
              assert_equal siblings.sort, ea.self_and_siblings.to_a.sort
              assert_equal((siblings - [ea]).sort, ea.siblings.to_a.sort)
            end
          end

          @expected_only_children.each do |ea|
            assert_equal [], ea.siblings
          end
        end

        it 'assembles before_siblings' do
          @expected_siblings.each do |siblings|
            (siblings.size - 1).times do |i|
              target = siblings[i]
              expected_before = siblings.first(i)
              assert_equal expected_before, target.siblings_before.to_a
            end
          end
        end

        it 'assembles after_siblings' do
          @expected_siblings.each do |siblings|
            (siblings.size - 1).times do |i|
              target = siblings[i]
              expected_after = siblings.last(siblings.size - 1 - i)
              assert_equal expected_after, target.siblings_after.to_a
            end
          end
        end

        it 'should assemble instance leaves' do
          { @a1 => [@b1b, @c1a, @c1b, @c1c], @b1 => [@c1a, @c1b, @c1c], @a2 => [@b2] }.each do |node, leaves|
            assert_equal leaves, node.leaves.to_a
          end

          @expected_leaves.each { |ea| assert_equal [ea], ea.leaves.to_a }
        end

        it 'should return leaf? for leaves' do
          @expected_leaves.each { |ea| assert ea.leaf? }
        end

        it 'can move roots' do
          @c1a.children << @a2
          @b2.reload.children << @a3
          assert_equal %w[a1 b1 c1a a2 b2 a3], @a3.reload.ancestry_path
        end

        it 'cascade-deletes from roots' do
          victim_names = @a1.self_and_descendants.map(&:name)
          survivor_names = @tag_class.all.map(&:name) - victim_names
          @a1.destroy
          assert_equal survivor_names, @tag_class.all.map(&:name)
        end
      end

      describe 'with_ancestor' do
        it 'works with no rows' do
          assert_empty @tag_class.with_ancestor.to_a
        end

        it 'finds only children' do
          c = @tag_class.find_or_create_by_path %w[A B C]
          a = c.parent.parent
          b = c.parent
          @tag_class.find_or_create_by_path %w[D E]
          assert_equal [b, c], @tag_class.with_ancestor(a).to_a
        end

        it 'limits subsequent where clauses' do
          a1c = @tag_class.find_or_create_by_path %w[A1 B C]
          a2c = @tag_class.find_or_create_by_path %w[A2 B C]
          # different paths!
          refute_equal a2c, a1c
          assert_equal [a1c, a2c].sort, @tag_class.where(name: 'C').to_a.sort
          assert_equal [a1c], @tag_class.with_ancestor(a1c.parent.parent).where(name: 'C').to_a.sort
        end
      end

      describe 'with_descendant' do
        it 'works with no rows' do
          assert_empty @tag_class.with_descendant.to_a
        end

        it 'finds only parents' do
          c = @tag_class.find_or_create_by_path %w[A B C]
          a = c.parent.parent
          b = c.parent
          spurious_tags = @tag_class.find_or_create_by_path %w[D E]
          assert_equal [a, b], @tag_class.with_descendant(c).to_a
        end

        it 'limits subsequent where clauses' do
          ac1 = @tag_class.create(name: 'A')
          ac2 = @tag_class.create(name: 'A')

          c1 = @tag_class.find_or_create_by_path %w[B C1]
          ac1.children << c1.parent

          c2 = @tag_class.find_or_create_by_path %w[B C2]
          ac2.children << c2.parent

          # different paths!
          refute_equal ac2, ac1
          assert_equal [ac1, ac2].sort, @tag_class.where(name: 'A').to_a.sort
          assert_equal [ac1], @tag_class.with_descendant(c1).where(name: 'A').to_a
        end
      end

      describe 'lowest_common_ancestor' do
        before do
          @t1 = @tag_class.create!(name: 't1')
          @t11 = @tag_class.create!(name: 't11', parent: @t1)
          @t111 = @tag_class.create!(name: 't111', parent: @t11)
          @t112 = @tag_class.create!(name: 't112', parent: @t11)
          @t12 = @tag_class.create!(name: 't12', parent: @t1)
          @t121 = @tag_class.create!(name: 't121', parent: @t12)
          @t2 = @tag_class.create!(name: 't2')
          @t21 = @tag_class.create!(name: 't21', parent: @t2)
          @t21 = @tag_class.create!(name: 't21', parent: @t2)
          @t211 = @tag_class.create!(name: 't211', parent: @t21)
        end

        it 'finds the parent for siblings' do
          assert_equal @t11, @tag_class.lowest_common_ancestor(@t112, @t111)
          assert_equal @t1, @tag_class.lowest_common_ancestor(@t12, @t11)

          assert_equal @t11, @tag_class.lowest_common_ancestor([@t112, @t111])
          assert_equal @t1, @tag_class.lowest_common_ancestor([@t12, @t11])

          assert_equal @t11, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t112 t111]))
          assert_equal @t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t12 t11]))
        end

        it 'finds the grandparent for cousins' do
          assert_equal @t1, @tag_class.lowest_common_ancestor(@t112, @t111, @t121)
          assert_equal @t1, @tag_class.lowest_common_ancestor([@t112, @t111, @t121])
          assert_equal @t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t112 t111 t121]))
        end

        it 'finds the parent/grandparent for aunt-uncle/niece-nephew' do
          assert_equal @t1, @tag_class.lowest_common_ancestor(@t12, @t112)
          assert_equal @t1, @tag_class.lowest_common_ancestor([@t12, @t112])
          assert_equal @t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t12 t112]))
        end

        it 'finds the self/parent for parent/child' do
          assert_equal @t12, @tag_class.lowest_common_ancestor(@t12, @t121)
          assert_equal @t1, @tag_class.lowest_common_ancestor(@t1, @t12)

          assert_equal @t12, @tag_class.lowest_common_ancestor([@t12, @t121])
          assert_equal @t1, @tag_class.lowest_common_ancestor([@t1, @t12])

          assert_equal @t12, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t12 t121]))
          assert_equal @t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t1 t12]))
        end

        it 'finds the self/grandparent for grandparent/grandchild' do
          assert_equal @t2, @tag_class.lowest_common_ancestor(@t211, @t2)
          assert_equal @t1, @tag_class.lowest_common_ancestor(@t111, @t1)

          assert_equal @t2, @tag_class.lowest_common_ancestor([@t211, @t2])
          assert_equal @t1, @tag_class.lowest_common_ancestor([@t111, @t1])

          assert_equal @t2, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t211 t2]))
          assert_equal @t1, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t111 t1]))
        end

        it 'finds the grandparent for a whole extended family' do
          assert_equal @t1, @tag_class.lowest_common_ancestor(@t1, @t11, @t111, @t112, @t12, @t121)
          assert_equal @t2, @tag_class.lowest_common_ancestor(@t2, @t21, @t211)

          assert_equal @t1, @tag_class.lowest_common_ancestor([@t1, @t11, @t111, @t112, @t12, @t121])
          assert_equal @t2, @tag_class.lowest_common_ancestor([@t2, @t21, @t211])

          assert_equal @t1,
                       @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t1 t11 t111 t112 t12 t121]))
          assert_equal @t2, @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t2 t21 t211]))
        end

        it 'is nil for no items' do
          assert_nil @tag_class.lowest_common_ancestor
          assert_nil @tag_class.lowest_common_ancestor([])
          assert_nil @tag_class.lowest_common_ancestor(@tag_class.none)
        end

        it 'is nil if there are no common ancestors' do
          assert_nil @tag_class.lowest_common_ancestor(@t111, @t211)
          assert_nil @tag_class.lowest_common_ancestor([@t111, @t211])
          assert_nil @tag_class.lowest_common_ancestor(@tag_class.where(name: %w[t111 t211]))
        end

        it 'is itself for single item' do
          assert_equal @t111, @tag_class.lowest_common_ancestor(@t111)
          assert_equal @t2, @tag_class.lowest_common_ancestor(@t2)

          assert_equal @t111, @tag_class.lowest_common_ancestor([@t111])
          assert_equal @t2, @tag_class.lowest_common_ancestor([@t2])

          assert_equal @t111, @tag_class.lowest_common_ancestor(@tag_class.where(name: 't111'))
          assert_equal @t2, @tag_class.lowest_common_ancestor(@tag_class.where(name: 't2'))
        end
      end

      describe 'paths' do
        describe 'with grandchild ' do
          before do
            @child = @tag_class.find_or_create_by_path([
                                                         { name: 'grandparent', title: 'Nonnie' },
                                                         { name: 'parent', title: 'Mom' },
                                                         { name: 'child', title: 'Kid' }
                                                       ])
            @parent = @child.parent
            @grandparent = @parent.parent
          end

          it 'should build ancestry path' do
            assert_equal %w[grandparent parent child], @child.ancestry_path
            assert_equal %w[grandparent parent child], @child.ancestry_path(:name)
            assert_equal %w[Nonnie Mom Kid], @child.ancestry_path(:title)
          end

          it 'assembles ancestors' do
            assert_equal [@parent, @grandparent], @child.ancestors
            assert_equal [@child, @parent, @grandparent], @child.self_and_ancestors
          end

          it 'should find by path' do
            # class method:
            assert_equal @child, @tag_class.find_by_path(%w[grandparent parent child])
            # instance method:
            assert_equal @child, @parent.find_by_path(%w[child])
            assert_equal @child, @grandparent.find_by_path(%w[parent child])
            assert_nil @parent.find_by_path(%w[child larvae])
          end

          it 'should respect attribute hashes with both selection and creation' do
            expected_title = 'something else'
            attrs = { title: expected_title }
            existing_title = @grandparent.title
            new_grandparent = @tag_class.find_or_create_by_path(%w[grandparent], attrs)
            refute_equal @grandparent, new_grandparent
            assert_equal expected_title, new_grandparent.title
            assert_equal existing_title, @grandparent.reload.title
          end

          it 'should create a hierarchy with a given attribute' do
            expected_title = 'unicorn rainbows'
            attrs = { title: expected_title }
            child = @tag_class.find_or_create_by_path(%w[grandparent parent child], attrs)
            refute_equal @child, child
            [child, child.parent, child.parent.parent].each do |ea|
              assert_equal expected_title, ea.title
            end
          end
        end

        it 'finds correctly rooted paths' do
          decoy = @tag_class.find_or_create_by_path %w[a b c d]
          b_d = @tag_class.find_or_create_by_path %w[b c d]
          assert_equal b_d, @tag_class.find_by_path(%w[b c d])
          assert_nil @tag_class.find_by_path(%w[c d])
        end

        it 'find_by_path for 1 node' do
          b = @tag_class.find_or_create_by_path %w[a b]
          b2 = b.root.find_by_path(%w[b])
          assert_equal b, b2
        end

        it 'find_by_path for 2 nodes' do
          path = %w[a b c]
          c = @tag_class.find_or_create_by_path path
          permutations = path.permutation.to_a
          correct = %w[b c]
          assert_equal c, c.root.find_by_path(correct)
          (permutations - correct).each do |bad_path|
            assert_nil c.root.find_by_path(bad_path)
          end
        end

        it 'find_by_path for 3 nodes' do
          d = @tag_class.find_or_create_by_path %w[a b c d]
          assert_equal d, d.root.find_by_path(%w[b c d])
          assert_equal d, @tag_class.find_by_path(%w[a b c d])
          assert_nil @tag_class.find_by_path(%w[d])
        end

        it 'should return nil for missing nodes' do
          assert_nil @tag_class.find_by_path(%w[missing])
          assert_nil @tag_class.find_by_path(%w[grandparent missing])
          assert_nil @tag_class.find_by_path(%w[grandparent parent missing])
          assert_nil @tag_class.find_by_path(%w[grandparent parent missing child])
        end

        describe '.find_or_create_by_path' do
          it 'uses existing records' do
            grandparent = @tag_class.find_or_create_by_path(%w[grandparent])
            assert_equal grandparent, grandparent
            child = @tag_class.find_or_create_by_path(%w[grandparent parent child])
            assert_equal child, child
          end

          it 'creates 2-deep trees with strings' do
            subject = @tag_class.find_or_create_by_path(%w[events anniversary])
            assert_equal %w[events anniversary], subject.ancestry_path
          end

          it 'creates 2-deep trees with hashes' do
            subject = @tag_class.find_or_create_by_path([
                                                          { name: 'test1', title: 'TEST1' },
                                                          { name: 'test2', title: 'TEST2' }
                                                        ])
            assert_equal %w[test1 test2], subject.ancestry_path
            # `self_and_ancestors` and `ancestors` is ordered parent-first. (!!)
            assert_equal %w[TEST2 TEST1], subject.self_and_ancestors.map(&:title)
          end
        end
      end

      describe 'hash_tree' do
        before do
          @d1 = @tag_class.find_or_create_by_path %w[a b c1 d1]
          @c1 = @d1.parent
          @b = @c1.parent
          @a = @b.parent
          @a2 = @tag_class.create(name: 'a2')
          @b2 = @tag_class.find_or_create_by_path %w[a b2]
          @c3 = @tag_class.find_or_create_by_path %w[a3 b3 c3]
          @b3 = @c3.parent
          @a3 = @b3.parent

          @tree2 = {
            @a => { @b => {}, @b2 => {} }, @a2 => {}, @a3 => { @b3 => {} }
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
                @c1 => {}
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
                }
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
        end

        describe '#hash_tree' do
          it 'returns {} for depth 0' do
            assert_equal({}, @tag_class.hash_tree(limit_depth: 0))
          end

          it 'limit_depth 1' do
            assert_equal @one_tree, @tag_class.hash_tree(limit_depth: 1)
          end

          it 'limit_depth 2' do
            assert_equal @two_tree, @tag_class.hash_tree(limit_depth: 2)
          end

          it 'limit_depth 3' do
            assert_equal @three_tree, @tag_class.hash_tree(limit_depth: 3)
          end

          it 'limit_depth 4' do
            assert_equal @full_tree, @tag_class.hash_tree(limit_depth: 4)
          end

          it 'no limit' do
            assert_equal @full_tree, @tag_class.hash_tree
          end
        end

        describe '.hash_tree' do
          it 'returns {} for depth 0' do
            assert_equal({}, @b.hash_tree(limit_depth: 0))
          end

          it 'limit_depth 1' do
            assert_equal @two_tree[@a].slice(@b), @b.hash_tree(limit_depth: 1)
          end

          it 'limit_depth 2' do
            assert_equal @three_tree[@a].slice(@b), @b.hash_tree(limit_depth: 2)
          end

          it 'limit_depth 3' do
            assert_equal @full_tree[@a].slice(@b), @b.hash_tree(limit_depth: 3)
          end

          it 'no limit from subsubroot' do
            assert_equal @full_tree[@a][@b].slice(@c1), @c1.hash_tree
          end

          it 'no limit from subroot' do
            assert_equal @full_tree[@a].slice(@b), @b.hash_tree
          end

          it 'no limit from root' do
            assert_equal @full_tree.slice(@a, @a2), @a.hash_tree.merge(@a2.hash_tree)
          end
        end

        describe '.hash_tree from relations' do
          it 'limit_depth 2 from chained activerecord association subroots' do
            assert_equal @three_tree[@a], @a.children.hash_tree(limit_depth: 2)
          end

          it 'no limit from chained activerecord association subroots' do
            assert_equal @full_tree[@a], @a.children.hash_tree
          end

          it 'limit_depth 3 from b.parent' do
            assert_equal @three_tree.slice(@a), @b.parent.hash_tree(limit_depth: 3)
          end

          it 'no limit_depth from b.parent' do
            assert_equal @full_tree.slice(@a), @b.parent.hash_tree
          end

          it 'no limit_depth from c.parent' do
            assert_equal @full_tree[@a].slice(@b), @c1.parent.hash_tree
          end
        end
      end

      it 'finds_by_path for very deep trees' do
        path = (1..20).to_a.map(&:to_s)
        subject = @tag_class.find_or_create_by_path(path)
        assert_equal path, subject.ancestry_path
        assert_equal subject, @tag_class.find_by_path(path)
        root = subject.root
        assert_equal subject, root.find_by_path(path[1..])
      end

      describe 'DOT rendering' do
        it 'should render for an empty scope' do
          assert_equal "digraph G {\n}\n", @tag_class.to_dot_digraph(@tag_class.where('0=1'))
        end

        it 'should render for an empty scope' do
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
      end
    end
  end
end

require 'spec_helper'

shared_examples_for "Tag (without fixtures)" do

  let (:tag_class) { described_class }
  let (:tag_hierarchy_class) { described_class.hierarchy_class }

  context 'class setup' do

    it 'has correct accessible_attributes' do
      if tag_class._ct.use_attr_accessible?
        tag_class.accessible_attributes.to_a.should =~ %w(parent name title)
      end
    end

    it 'should build hierarchy classname correctly' do
      tag_class.hierarchy_class.should == tag_hierarchy_class
      tag_class._ct.hierarchy_class_name.should == tag_hierarchy_class.to_s
      tag_class._ct.short_hierarchy_class_name.should == tag_hierarchy_class.to_s
    end

    it 'should have a correct parent column name' do
      expected_parent_column_name = tag_class == UUIDTag ? "parent_uuid" : "parent_id"
      tag_class._ct.parent_column_name.should == expected_parent_column_name
    end
  end

  describe "from empty db" do

    context "with no tags" do
      it "should return no entities" do
        tag_class.roots.should be_empty
        tag_class.leaves.should be_empty
      end

      it "#find_or_create_by_path" do
        a = tag_class.create!(:name => 'a')
        a.find_or_create_by_path(%w{b c}).ancestry_path.should == %w{a b c}
      end
    end

    context "with 1 tag" do
      before do
        @tag = tag_class.create!(:name => "tag")
      end

      it "should be a leaf" do
        @tag.leaf?.should be_true
      end

      it "should be a root" do
        @tag.root?.should be_true
      end

      it 'has no parent' do
        @tag.parent.should be_nil
      end

      it "should return the only entity as a root and leaf" do
        tag_class.all.should == [@tag]
        tag_class.roots.should == [@tag]
        tag_class.leaves.should == [@tag]
      end

      context "with child" do
        before do
          @child = Tag.create!(:name => 'tag 2')
        end

        def assert_roots_and_leaves
          @tag.root?.should be_true
          @tag.leaf?.should be_false

          @child.root?.should be_false
          @child.leaf?.should be_true
        end

        def assert_parent_and_children
          @child.reload.parent.should == @tag
          @tag.reload.children.to_a.should == [ @child ]
        end

        it "adds children through add_child" do
          @tag.add_child @child
          assert_roots_and_leaves
          assert_parent_and_children
        end

        it "adds children through collection" do
          @tag.children << @child
          assert_roots_and_leaves
          assert_parent_and_children
        end
      end
    end

    context "with 2 tags" do
      before :each do
        @root = tag_class.create!(:name => "root")
        @leaf = @root.add_child(tag_class.create!(:name => "leaf"))
      end
      it "should return a simple root and leaf" do
        tag_class.roots.should == [@root]
        tag_class.leaves.should == [@leaf]
      end
      it "should return child_ids for root" do
        @root.child_ids.should == [@leaf.id]
      end

      it "should return an empty array for leaves" do
        @leaf.child_ids.should be_empty
      end
    end

    context "3 tag collection.create db" do
      before :each do
        @root = tag_class.create! :name => "root"
        @mid = @root.children.create! :name => "mid"
        @leaf = @mid.children.create! :name => "leaf"
        DestroyedTag.delete_all
      end

      it "should create all tags" do
        tag_class.all.to_a.should =~ [@root, @mid, @leaf]
      end

      it "should return a root and leaf without middle tag" do
        tag_class.roots.should == [@root]
        tag_class.leaves.should == [@leaf]
      end

      it "should delete leaves" do
        tag_class.leaves.destroy_all
        tag_class.roots.should == [@root] # untouched
        tag_class.leaves.should == [@mid]
      end

      it "should delete everything if you delete the roots" do
        tag_class.roots.destroy_all
        tag_class.all.should be_empty
        tag_class.roots.should be_empty
        tag_class.leaves.should be_empty
        DestroyedTag.all.map { |t| t.name }.should =~ %w{root mid leaf}
      end

      it 'fix self_and_ancestors properly on reparenting' do
        t = tag_class.create! :name => 'moar leaf'
        t.self_and_ancestors.to_a.should == [t]
        @mid.children << t
        t.self_and_ancestors.to_a.should == [t, @mid, @root]
      end

      it 'prevents ancestor loops' do
        @leaf.add_child @root
        @root.should_not be_valid
        @root.reload.descendants.should include(@leaf)
      end

      it 'moves non-leaves' do
        new_root = tag_class.create! :name => "new_root"
        new_root.children << @mid
        @root.reload.descendants.should be_empty
        new_root.descendants.should == [@mid, @leaf]
        @leaf.reload.ancestry_path.should == %w{new_root mid leaf}
      end

      it 'moves leaves' do
        new_root = tag_class.create! :name => "new_root"
        new_root.children << @leaf
        new_root.descendants.should == [@leaf]
        @root.reload.descendants.should == [@mid]
        @leaf.reload.ancestry_path.should == %w{new_root leaf}
      end
    end

    context "3 tag explicit_create db" do
      before :each do
        @root = tag_class.create!(:name => "root")
        @mid = @root.add_child(tag_class.create!(:name => "mid"))
        @leaf = @mid.add_child(tag_class.create!(:name => "leaf"))
      end

      it "should create all tags" do
        tag_class.all.to_a.should =~ [@root, @mid, @leaf]
      end

      it "should return a root and leaf without middle tag" do
        tag_class.roots.should == [@root]
        tag_class.leaves.should == [@leaf]
      end

      it "should prevent parental loops from torso" do
        @mid.children << @root
        @root.valid?.should be_false
        @mid.reload.children.should == [@leaf]
      end

      it "should prevent parental loops from toes" do
        @leaf.children << @root
        @root.valid?.should be_false
        @leaf.reload.children.should be_empty
      end

      it "should support re-parenting" do
        @root.children << @leaf
        tag_class.leaves.should == [@leaf, @mid]
      end

      it "cleans up hierarchy references for leaves" do
        @leaf.destroy
        tag_hierarchy_class.where(:ancestor_id => @leaf.id).should be_empty
        tag_hierarchy_class.where(:descendant_id => @leaf.id).should be_empty
      end

      it "cleans up hierarchy references" do
        @mid.destroy
        tag_hierarchy_class.where(:ancestor_id => @mid.id).should be_empty
        tag_hierarchy_class.where(:descendant_id => @mid.id).should be_empty
        @root.reload.should be_root
        root_hiers = @root.ancestor_hierarchies.to_a
        root_hiers.size.should == 1
        tag_hierarchy_class.where(:ancestor_id => @root.id).should == root_hiers
        tag_hierarchy_class.where(:descendant_id => @root.id).should == root_hiers
      end

      it "should have different hash codes for each hierarchy model" do
        hashes = tag_hierarchy_class.all.map(&:hash)
        hashes.should =~ hashes.uniq
      end

      it "should return the same hash code for equal hierarchy models" do
        tag_hierarchy_class.first.hash.should == tag_hierarchy_class.first.hash
      end
    end

    it "performs as the readme says it does" do
      grandparent = tag_class.create(:name => 'Grandparent')
      parent = grandparent.children.create(:name => 'Parent')
      child1 = tag_class.create(:name => 'First Child', :parent => parent)
      child2 = tag_class.new(:name => 'Second Child')
      parent.children << child2
      child3 = tag_class.new(:name => 'Third Child')
      parent.add_child child3
      grandparent.self_and_descendants.collect(&:name).should ==
        ["Grandparent", "Parent", "First Child", "Second Child", "Third Child"]
      child1.ancestry_path.should ==
        ["Grandparent", "Parent", "First Child"]
      child3.ancestry_path.should ==
        ["Grandparent", "Parent", "Third Child"]
      d = tag_class.find_or_create_by_path %w(a b c d)
      h = tag_class.find_or_create_by_path %w(e f g h)
      e = h.root
      d.add_child(e) # "d.children << e" would work too, of course
      h.ancestry_path.should == %w(a b c d e f g h)
    end

    it "roots sort alphabetically" do
      expected = ("a".."z").to_a
      expected.shuffle.each { |ea| tag_class.create!(:name => ea) }
      tag_class.roots.collect { |ea| ea.name }.should == expected
    end

    context "with simple tree" do
      before :each do
        tag_class.find_or_create_by_path %w(a1 b1 c1a)
        tag_class.find_or_create_by_path %w(a1 b1 c1b)
        tag_class.find_or_create_by_path %w(a2 b2)
        tag_class.find_or_create_by_path %w(a3)

        @a1, @a2, @a3, @b1, @b2, @c1a, @c1b = tag_class.where(:name => %w(a1 a2 a3 b1 b2 c1a c1b)).reorder(:name).to_a
        @expected_roots = [@a1, @a2, @a3]
        @expected_leaves = [@c1a, @c1b, @b2, @a3]
      end
      it 'should find global roots' do
        tag_class.roots.to_a.should =~ @expected_roots
      end
      it 'should return root? for roots' do
        @expected_roots.each { |ea| ea.should be_root }
      end
      it 'should not return root? for non-roots' do
        [@b1, @b2, @c1a, @c1b].each { |ea| ea.should_not be_root }
      end
      it 'should return the correct root' do
        {@a1 => @a1, @a2 => @a2, @a3 => @a3,
          @b1 => @a1, @b2 => @a2, @c1a => @a1, @c1b => @a1}.each do |node, root|
          node.root.should == root
        end
      end
      it 'should assemble global leaves' do
        tag_class.leaves.to_a.should =~ @expected_leaves
      end
      it 'assembles siblings properly' do
        expected_siblings = [[@a1, @a2, @a3], [@c1a, @c1b]]
        expected_only_children = tag_class.all - expected_siblings.flatten
        expected_siblings.each do |siblings|
          siblings.each do |ea|
            ea.self_and_siblings.to_a.should =~ siblings
            ea.siblings.to_a.should =~ siblings - [ ea ]
          end
        end
        expected_only_children.each do |ea|
          ea.siblings.should == []
        end
      end
      it 'should assemble instance leaves' do
        {@a1 => [@c1a, @c1b], @b1 => [@c1a, @c1b], @a2 => [@b2]}.each do |node, leaves|
          node.leaves.to_a.should == leaves
        end
        @expected_leaves.each { |ea| ea.leaves.to_a.should == [ea] }
      end
      it 'should return leaf? for leaves' do
        @expected_leaves.each { |ea| ea.should be_leaf }
      end

      it 'can move roots' do
        @c1a.children << @a2
        @b2.reload.children << @a3
        @a3.reload.ancestry_path.should ==%w(a1 b1 c1a a2 b2 a3)
      end

      it 'cascade-deletes from roots' do
        victim_names = @a1.self_and_descendants.map(&:name)
        survivor_names = tag_class.all.map(&:name) - victim_names
        @a1.destroy
        tag_class.all.map(&:name).should == survivor_names
      end
    end

    context 'with_ancestor' do
      it 'works with no rows' do
        tag_class.with_ancestor().to_a.should be_empty
      end
      it 'finds only children' do
        c = tag_class.find_or_create_by_path %w(A B C)
        a, b = c.parent.parent, c.parent
        e = tag_class.find_or_create_by_path %w(D E)
        tag_class.with_ancestor(a).to_a.should == [b, c]
      end
      it 'limits subsequent where clauses' do
        a1c = tag_class.find_or_create_by_path %w(A1 B C)
        a2c = tag_class.find_or_create_by_path %w(A2 B C)
        tag_class.where(:name => "C").to_a.should =~ [a1c, a2c]
        tag_class.with_ancestor(a1c.parent.parent).where(:name => "C").to_a.should == [a1c]
      end
    end

    context "paths" do
      before :each do
        @child = tag_class.find_or_create_by_path(%w(grandparent parent child))
        @child.title = "Kid"
        @parent = @child.parent
        @parent.title = "Mom"
        @grandparent = @parent.parent
        @grandparent.title = "Nonnie"
        [@child, @parent, @grandparent].each { |ea| ea.save! }
      end

      it "should build ancestry path" do
        @child.ancestry_path.should == %w{grandparent parent child}
        @child.ancestry_path(:name).should == %w{grandparent parent child}
        @child.ancestry_path(:title).should == %w{Nonnie Mom Kid}
      end

      it "should find by path" do
        # class method:
        tag_class.find_by_path(%w{grandparent parent child}).should == @child
        # instance method:
        @parent.find_by_path(%w{child}).should == @child
        @grandparent.find_by_path(%w{parent child}).should == @child
        @parent.find_by_path(%w{child larvae}).should be_nil
      end

      it "finds correctly rooted paths" do
        decoy = tag_class.find_or_create_by_path %w(a b c d)
        b_d = tag_class.find_or_create_by_path %w(b c d)
        tag_class.find_by_path(%w(b c d)).should == b_d
        tag_class.find_by_path(%w(c d)).should be_nil
      end

      it "find_by_path for 1 node" do
        b = tag_class.find_or_create_by_path %w(a b)
        b2 = b.root.find_by_path(%w(b))
        b2.should == b
      end

      it "find_by_path for 2 nodes" do
        c = tag_class.find_or_create_by_path %w(a b c)
        c.root.find_by_path(%w(b c)).should == c
        c.root.find_by_path(%w(a c)).should be_nil
        c.root.find_by_path(%w(c)).should be_nil
      end

      it "find_by_path for 3 nodes" do
        d = tag_class.find_or_create_by_path %w(a b c d)
        d.root.find_by_path(%w(b c d)).should == d
        tag_class.find_by_path(%w(a b c d)).should == d
        tag_class.find_by_path(%w(d)).should be_nil
      end

      it "should return nil for missing nodes" do
        tag_class.find_by_path(%w{missing}).should be_nil
        tag_class.find_by_path(%w{grandparent missing}).should be_nil
        tag_class.find_by_path(%w{grandparent parent missing}).should be_nil
        tag_class.find_by_path(%w{grandparent parent missing child}).should be_nil
      end

      it ".find_or_create_by_path" do
        grandparent = tag_class.find_or_create_by_path(%w{grandparent})
        grandparent.should == @grandparent
        child = tag_class.find_or_create_by_path(%w{grandparent parent child})
        child.should == @child
        tag_class.find_or_create_by_path(%w{events anniversary}).ancestry_path.should == %w{events anniversary}
      end

      it "should respect attribute hashes with both selection and creation" do
        expected_title = 'something else'
        attrs = {:title => expected_title}
        existing_title = @grandparent.title
        new_grandparent = tag_class.find_or_create_by_path(%w{grandparent}, attrs)
        new_grandparent.should_not == @grandparent
        new_grandparent.title.should == expected_title
        @grandparent.reload.title.should == existing_title
      end

      it "should create a hierarchy with a given attribute" do
        expected_title = 'unicorn rainbows'
        attrs = {:title => expected_title}
        child = tag_class.find_or_create_by_path(%w{grandparent parent child}, attrs)
        child.should_not == @child
        [child, child.parent, child.parent.parent].each do |ea|
          ea.title.should == expected_title
        end
      end
    end

    context "hash_tree" do

      before :each do
        @b = tag_class.find_or_create_by_path %w(a b)
        @a = @b.parent
        @b2 = tag_class.find_or_create_by_path %w(a b2)
        @d1 = @b.find_or_create_by_path %w(c1 d1)
        @c1 = @d1.parent
        @d2 = @b.find_or_create_by_path %w(c2 d2)
        @c2 = @d2.parent
        @full_tree = {@a => {@b => {@c1 => {@d1 => {}}, @c2 => {@d2 => {}}}, @b2 => {}}}
        #File.open("example.dot", "w") { |f| f.write(tag_class.root.to_dot_digraph) }
      end

      context "#hash_tree" do
        it "returns {} for depth 0" do
          tag_class.hash_tree(:limit_depth => 0).should == {}
        end
        it "limit_depth 1" do
          tag_class.hash_tree(:limit_depth => 1).should == {@a => {}}
        end
        it "limit_depth 2" do
          tag_class.hash_tree(:limit_depth => 2).should == {@a => {@b => {}, @b2 => {}}}
        end
        it "limit_depth 3" do
          tag_class.hash_tree(:limit_depth => 3).should == {@a => {@b => {@c1 => {}, @c2 => {}}, @b2 => {}}}
        end
        it "limit_depth 4" do
          tag_class.hash_tree(:limit_depth => 4).should == @full_tree
        end
        it "no limit holdum" do
          tag_class.hash_tree.should == @full_tree
        end
      end

      def assert_no_dupes(scope)
        # the named scope is complicated enough that an incorrect join could result in unnecessarily
        # duplicated rows:
        a = scope.collect { |ea| ea.id }
        a.should == a.uniq
      end

      context "#hash_tree_scope" do
        it "no dupes for any depth" do
          (0..5).each do |ea|
            assert_no_dupes(tag_class.hash_tree_scope(ea))
          end
        end
        it "no limit holdum" do
          assert_no_dupes(tag_class.hash_tree_scope)
        end
      end

      context ".hash_tree_scope" do
        it "no dupes for any depth" do
          (0..5).each do |ea|
            assert_no_dupes(@a.hash_tree_scope(ea))
          end
        end
        it "no limit holdum" do
          assert_no_dupes(@a.hash_tree_scope)
        end
      end

      context ".hash_tree" do
        before :each do
        end
        it "returns {} for depth 0" do
          @b.hash_tree(:limit_depth => 0).should == {}
        end
        it "limit_depth 1" do
          @b.hash_tree(:limit_depth => 1).should == {@b => {}}
        end
        it "limit_depth 2" do
          @b.hash_tree(:limit_depth => 2).should == {@b => {@c1 => {}, @c2 => {}}}
        end
        it "limit_depth 3" do
          @b.hash_tree(:limit_depth => 3).should == {@b => {@c1 => {@d1 => {}}, @c2 => {@d2 => {}}}}
        end
        it "no limit holdum from subsubroot" do
          @c1.hash_tree.should == {@c1 => {@d1 => {}}}
        end
        it "no limit holdum from subroot" do
          @b.hash_tree.should == {@b => {@c1 => {@d1 => {}}, @c2 => {@d2 => {}}}}
        end
        it "no limit holdum from root" do
          @a.hash_tree.should == @full_tree
        end
      end
    end

    describe 'very deep trees' do
      it 'should find_or_create very deep nodes' do
        expected_ancestry_path = (1..200).to_a.map { |ea| ea.to_s }
        target = tag_class.find_or_create_by_path(expected_ancestry_path)
        target.ancestry_path.should == expected_ancestry_path
      end
    end

    describe 'DOT rendering' do
      it 'should render for an empty scope' do
        tag_class.to_dot_digraph(tag_class.where("0=1")).should == "digraph G {\n}\n"
      end
      it 'should render for an empty scope' do
        tag_class.find_or_create_by_path(%w(a b1 c1))
        tag_class.find_or_create_by_path(%w(a b2 c2))
        tag_class.find_or_create_by_path(%w(a b2 c3))
        a, b1, b2, c1, c2, c3 = %w(a b1 b2 c1 c2 c3).map { |ea| tag_class.where(:name => ea).first.id }
        dot = tag_class.roots.first.to_dot_digraph
        dot.should == <<-DOT
digraph G {
  #{a} [label="a"]
  #{a} -> #{b1}
  #{b1} [label="b1"]
  #{a} -> #{b2}
  #{b2} [label="b2"]
  #{b1} -> #{c1}
  #{c1} [label="c1"]
  #{b2} -> #{c2}
  #{c2} [label="c2"]
  #{b2} -> #{c3}
  #{c3} [label="c3"]
}
        DOT
      end
    end
  end
end

require 'spec_helper'

shared_examples_for Tag do

  it "has correct accessible_attributes" do
    Tag.accessible_attributes.to_a.should =~ %w(parent name)
  end

  describe "empty db" do

    def nuke_db
      TagHierarchy.delete_all
      Tag.delete_all
    end

    before :each do
      nuke_db
    end

    context "empty db" do
      it "should return no entities" do
        Tag.roots.should be_empty
        Tag.leaves.should be_empty
      end
    end

    context "1 tag db" do
      it "should return the only entity as a root and leaf" do
        a = Tag.create!(:name => "a")
        Tag.roots.should == [a]
        Tag.leaves.should == [a]
      end
    end

    context "2 tag db" do
      it "should return a simple root and leaf" do
        root = Tag.create!(:name => "root")
        leaf = root.add_child(Tag.create!(:name => "leaf"))
        Tag.roots.should == [root]
        Tag.leaves.should == [leaf]
      end
    end

    context "3 tag collection.create db" do
      before :each do
        @root = Tag.create! :name => "root"
        @mid = @root.children.create! :name => "mid"
        @leaf = @mid.children.create! :name => "leaf"
        DestroyedTag.delete_all
      end

      it "should create all tags" do
        Tag.all.should =~ [@root, @mid, @leaf]
      end

      it "should return a root and leaf without middle tag" do
        Tag.roots.should == [@root]
        Tag.leaves.should == [@leaf]
      end

      it "should delete leaves" do
        Tag.leaves.destroy_all
        Tag.roots.should == [@root] # untouched
        Tag.leaves.should == [@mid]
      end

      it "should delete everything if you delete the roots" do
        Tag.roots.destroy_all
        Tag.all.should be_empty
        Tag.roots.should be_empty
        Tag.leaves.should be_empty
        DestroyedTag.all.collect { |t| t.name }.should =~ %w{root mid leaf}
      end
    end

    context "3 tag explicit_create db" do
      before :each do
        @root = Tag.create!(:name => "root")
        @mid = @root.add_child(Tag.create!(:name => "mid"))
        @leaf = @mid.add_child(Tag.create!(:name => "leaf"))
      end

      it "should create all tags" do
        Tag.all.should =~ [@root, @mid, @leaf]
      end

      it "should return a root and leaf without middle tag" do
        Tag.roots.should == [@root]
        Tag.leaves.should == [@leaf]
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
        Tag.leaves.should == [@leaf, @mid]
      end

      it "cleans up hierarchy references for leaves" do
        @leaf.destroy
        TagHierarchy.find_all_by_ancestor_id(@leaf.id).should be_empty
        TagHierarchy.find_all_by_descendant_id(@leaf.id).should be_empty
      end

      it "cleans up hierarchy references" do
        @mid.destroy
        TagHierarchy.find_all_by_ancestor_id(@mid.id).should be_empty
        TagHierarchy.find_all_by_descendant_id(@mid.id).should be_empty
        @root.reload.should be_root
        root_hiers = @root.ancestor_hierarchies.to_a
        root_hiers.size.should == 1
        TagHierarchy.find_all_by_ancestor_id(@root.id).should == root_hiers
        TagHierarchy.find_all_by_descendant_id(@root.id).should == root_hiers
      end
    end

    it "builds hash_trees properly" do
      b = Tag.find_or_create_by_path %w(a b)
      a = b.parent
      b2 = Tag.find_or_create_by_path %w(a b2)
      d1 = b.find_or_create_by_path %w(c1 d1)
      c1 = d1.parent
      d2 = b.find_or_create_by_path %w(c2 d2)
      c2 = d2.parent
      Tag.hash_tree(:limit_depth => 0).should == {}
      Tag.hash_tree(:limit_depth => 1).should == {a => {}}
      Tag.hash_tree(:limit_depth => 2).should == {a => {b => {}, b2 => {}}}
      tree = {a => {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}, b2 => {}}}
      Tag.hash_tree(:limit_depth => 4).should == tree
      Tag.hash_tree.should == tree
      b.hash_tree(:limit_depth => 0).should == {}
      b.hash_tree(:limit_depth => 1).should == {b => {}}
      b.hash_tree(:limit_depth => 2).should == {b => {c1 => {}, c2 => {}}}
      b_tree = {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}}
      b.hash_tree(:limit_depth => 3).should == b_tree
      b.hash_tree.should == b_tree
    end

    it "performs as the readme says it does" do
      grandparent = Tag.create(:name => 'Grandparent')
      parent = grandparent.children.create(:name => 'Parent')
      child1 = Tag.create(:name => 'First Child', :parent => parent)
      child2 = Tag.new(:name => 'Second Child')
      parent.children << child2
      child3 = Tag.new(:name => 'Third Child')
      parent.add_child child3
      grandparent.self_and_descendants.collect(&:name).should ==
        ["Grandparent", "Parent", "First Child", "Second Child", "Third Child"]
      child1.ancestry_path.should ==
        ["Grandparent", "Parent", "First Child"]
      child3.ancestry_path.should ==
        ["Grandparent", "Parent", "Third Child"]
      d = Tag.find_or_create_by_path %w(a b c d)
      h = Tag.find_or_create_by_path %w(e f g h)
      e = h.root
      d.add_child(e) # "d.children << e" would work too, of course
      h.ancestry_path.should == %w(a b c d e f g h)
    end

  end

  describe "Tag with fixtures" do

    fixtures :tags

    before :each do
      Tag.rebuild!
      DestroyedTag.delete_all
    end

    context "class injection" do
      it "should build hierarchy classname correctly" do
        Tag.hierarchy_class.to_s.should == "TagHierarchy"
        Tag.hierarchy_class_name.should == "TagHierarchy"
      end

      it "should have a correct parent column name" do
        Tag.parent_column_name.should == "parent_id"
      end
    end

    context "roots" do
      it "should find global roots" do
        roots = Tag.roots.to_a
        roots.should be_member(tags(:people))
        roots.should be_member(tags(:events))
        roots.should_not be_member(tags(:child))
        tags(:people).root?.should be_true
        tags(:child).root?.should be_false
      end

      it "should find an instance root" do
        tags(:grandparent).root.should == tags(:grandparent)
        tags(:parent).root.should == tags(:grandparent)
        tags(:child).root.should == tags(:grandparent)
      end
    end

    context "leaves" do
      it "should assemble global leaves" do
        Tag.leaves.size.should > 0
        Tag.leaves.each { |t| t.children.should be_empty, "#{t.name} was returned by leaves but has children: #{t.children}" }
        Tag.leaves.each { |t| t.should be_leaf, "{t.name} was returned by leaves but was not a leaf" }
      end

      it "should assemble instance leaves" do
        tags(:grandparent).leaves.should == [tags(:child)]
        tags(:parent).leaves.should == [tags(:child)]
        tags(:child).leaves.should == [tags(:child)]
      end
    end

    context "adding children" do
      it "should work explicitly" do
        sb = Tag.create!(:name => "Santa Barbara")
        sb.leaf?.should_not be_nil
        tags(:california).add_child sb
        sb.leaf?.should_not be_nil
        validate_city_tag sb
      end

      it "should work implicitly through the collection" do
        eg = Tag.create!(:name => "El Granada")
        eg.leaf?.should_not be_nil
        tags(:california).children << eg
        eg.leaf?.should_not be_nil
        validate_city_tag eg
      end

      it "should fail to create ancestor loops" do
        child = tags(:child)
        parent = child.parent
        child.add_child(parent) # this should fail
        parent.valid?.should be_false
        child.reload.children.should be_empty
        parent.reload.children.should == [child]
      end

      it "should move non-leaves" do
        # This is what the fixture should encode:
        tags(:d2).ancestry_path.should == %w{a1 b2 c2 d2}
        tags(:b1).add_child(tags(:c2))
        tags(:b2).leaf?.should_not be_nil
        tags(:b1).children.include?(tags(:c2)).should be_true
        tags(:d2).reload.ancestry_path.should == %w{a1 b1 c2 d2}
      end

      it "should move leaves" do
        l = Tag.find_or_create_by_path(%w{leaftest branch1 leaf})
        b2 = Tag.find_or_create_by_path(%w{leaftest branch2})
        b2.children << l
        l.ancestry_path.should == %w{leaftest branch2 leaf}
      end

      it "should move roots" do
        l1 = Tag.find_or_create_by_path(%w{roottest1 branch1 leaf1})
        l2 = Tag.find_or_create_by_path(%w{roottest2 branch2 leaf2})
        l1.children << l2.root
        l1.reload.ancestry_path.should == %w{roottest1 branch1 leaf1}
        l2.reload.ancestry_path.should == %w{roottest1 branch1 leaf1 roottest2 branch2 leaf2}
      end

      it "should cascade delete all children" do
        b2 = tags(:b2)
        entities = b2.self_and_descendants.to_a
        names = b2.self_and_descendants.collect { |t| t.name }
        b2.destroy
        entities.each { |e| Tag.find_by_id(e.id).should be_nil }
        DestroyedTag.all.collect { |t| t.name }.should =~ names
      end
    end

    context "injected attributes" do
      it "should compute level correctly" do
        tags(:grandparent).level.should == 0
        tags(:parent).level.should == 1
        tags(:child).level.should == 2
      end

      it "should determine parent correctly" do
        tags(:grandparent).parent.should == nil
        tags(:parent).parent.should == tags(:grandparent)
        tags(:child).parent.should == tags(:parent)
      end

      it "should have a sane children collection" do
        tags(:grandparent).children.include? tags(:parent).should be_true
        tags(:parent).children.include? tags(:child).should be_true
        tags(:child).children.should be_empty
      end

      it "assembles siblings correctly" do
        tags(:b1).siblings.to_a.should =~ [tags(:b2)]
        tags(:a1).siblings.to_a.should =~ (Tag.roots.to_a - [tags(:a1)])
        tags(:a1).self_and_siblings.to_a.should =~ Tag.roots.to_a

        # must be ordered
        tags(:indoor).siblings.to_a.should == [tags(:home), tags(:museum), tags(:outdoor), tags(:united_states)]
        tags(:indoor).self_and_siblings.to_a.should == [tags(:home), tags(:indoor), tags(:museum), tags(:outdoor), tags(:united_states)]
      end

      it "assembles siblings before correctly" do
        tags(:home).siblings_before.to_a.should == []
        tags(:indoor).siblings_before.to_a.should == [tags(:home)]
        tags(:outdoor).siblings_before.to_a.should == [tags(:home), tags(:indoor), tags(:museum)]
        tags(:united_states).siblings_before.to_a.should == [tags(:home), tags(:indoor), tags(:museum), tags(:outdoor)]
      end

      it "assembles siblings after correctly" do
        tags(:indoor).siblings_after.to_a.should == [tags(:museum), tags(:outdoor), tags(:united_states)]
        tags(:outdoor).siblings_after.to_a.should == [tags(:united_states)]
        tags(:united_states).siblings_after.to_a.should == []
      end

      it "assembles ancestors" do
        tags(:child).ancestors.should == [tags(:parent), tags(:grandparent)]
        tags(:child).self_and_ancestors.should == [tags(:child), tags(:parent), tags(:grandparent)]
      end

      it "assembles descendants" do
        tags(:parent).descendants.should == [tags(:child)]
        tags(:parent).self_and_descendants.should == [tags(:parent), tags(:child)]
        tags(:grandparent).descendants.should == [tags(:parent), tags(:child)]
        tags(:grandparent).self_and_descendants.should == [tags(:grandparent), tags(:parent), tags(:child)]
        tags(:grandparent).self_and_descendants.collect { |t| t.name }.join(" > ").should == "grandparent > parent > child"
      end
    end

    context "paths" do

      it "should build ancestry path" do
        tags(:child).ancestry_path.should == %w{grandparent parent child}
        tags(:child).ancestry_path(:name).should == %w{grandparent parent child}
        tags(:child).ancestry_path(:title).should == %w{Nonnie Mom Kid}
      end

      it "should find by path" do
        # class method:
        Tag.find_by_path(%w{grandparent parent child}).should == tags(:child)
        # instance method:
        tags(:parent).find_by_path(%w{child}).should == tags(:child)
        tags(:grandparent).find_by_path(%w{parent child}).should == tags(:child)
        tags(:parent).find_by_path(%w{child larvae}).should be_nil
      end

      it "should return nil for missing nodes" do
        Tag.find_by_path(%w{missing}).should be_nil
        Tag.find_by_path(%w{grandparent missing}).should be_nil
        Tag.find_by_path(%w{grandparent parent missing}).should be_nil
        Tag.find_by_path(%w{grandparent parent missing child}).should be_nil
      end

      it "should find or create by path" do
        # class method:
        grandparent = Tag.find_or_create_by_path(%w{grandparent})
        grandparent.should == tags(:grandparent)
        child = Tag.find_or_create_by_path(%w{grandparent parent child})
        child.should == tags(:child)
        Tag.find_or_create_by_path(%w{events anniversary}).ancestry_path.should == %w{events anniversary}
        a = Tag.find_or_create_by_path(%w{a})
        a.ancestry_path.should == %w{a}
        # instance method:
        a.find_or_create_by_path(%w{b c}).ancestry_path.should == %w{a b c}
      end
    end

    def validate_city_tag city
      tags(:california).children.include?(city).should_not be_nil
      city.ancestors.should == [tags(:california), tags(:united_states), tags(:places)]
      city.self_and_ancestors.should == [city, tags(:california), tags(:united_states), tags(:places)]
    end

  end
end

describe Tag do
  it_behaves_like Tag
end

describe "Tag with AR whitelisted attributes enabled" do
  before(:all) do
    ActiveRecord::Base.attr_accessible(nil) # turn on whitelisted attributes
    ActiveRecord::Base.descendants.each{|ea|ea.reset_column_information}
  end
  it_behaves_like Tag
end



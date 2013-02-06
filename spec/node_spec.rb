require 'spec_helper'

shared_examples_for Node do

  it "has correct accessible_attributes" do
    Node.accessible_attributes.to_a.should =~ %w(parent name)
  end

  describe "empty db" do

    def nuke_db
      NodeHierarchy.delete_all
      Node.delete_all
    end

    before :each do
      nuke_db
    end

    context "empty db" do
      it "should return no entities" do
        Node.roots.should be_empty
        Node.leaves.should be_empty
      end
    end

    context "1 node db" do
      it "should return the only entity as a root and leaf" do
        a = Node.create!(:name => "a")
        Node.roots.should == [a]
        Node.leaves.should == [a]
      end
    end

    context "2 node db" do
      it "should return a simple root and leaf" do
        root = Node.create!(:name => "root")
        leaf = root.add_child(Node.create!(:name => "leaf"))
        Node.roots.should == [root]
        Node.leaves.should == [leaf]
      end
    end

    context "3 node collection.create db" do
      before :each do
        @root = Node.create! :name => "root"
        @mid = @root.children.create! :name => "mid"
        @leaf = @mid.children.create! :name => "leaf"
      end

      it "should create all nodes" do
        Node.all.should =~ [@root, @mid, @leaf]
      end

      it "should return a root and leaf without middle node" do
        Node.roots.should == [@root]
        Node.leaves.should == [@leaf]
      end

      it "should delete leaves" do
        Node.leaves.destroy_all
        Node.roots.should == [@root] # untouched
        Node.leaves.should == [@mid]
      end

      it "should delete everything if you delete the roots" do
        Node.roots.destroy_all
        Node.all.should be_empty
        Node.roots.should be_empty
        Node.leaves.should be_empty
      end
    end

    context "3 node explicit_create db" do
      before :each do
        @root = Node.create!(:name => "root")
        @mid = @root.add_child(Node.create!(:name => "mid"))
        @leaf = @mid.add_child(Node.create!(:name => "leaf"))
      end

      it "should create all nodes" do
        Node.all.should =~ [@root, @mid, @leaf]
      end

      it "should return a root and leaf without middle node" do
        Node.roots.should == [@root]
        Node.leaves.should == [@leaf]
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
        Node.leaves.should =~ [@leaf, @mid]
      end

      it "cleans up hierarchy references for leaves" do
        @leaf.destroy
        NodeHierarchy.find_all_by_ancestor_id(@leaf.id).should be_empty
        NodeHierarchy.find_all_by_descendant_id(@leaf.id).should be_empty
      end

      it "cleans up hierarchy references" do
        @mid.destroy
        NodeHierarchy.find_all_by_ancestor_id(@mid.id).should be_empty
        NodeHierarchy.find_all_by_descendant_id(@mid.id).should be_empty
        @root.reload.should be_root
        root_hiers = @root.ancestor_hierarchies.to_a
        root_hiers.size.should == 1
        NodeHierarchy.find_all_by_ancestor_id(@root.id).should == root_hiers
        NodeHierarchy.find_all_by_descendant_id(@root.id).should == root_hiers
      end
    end

    it "performs as the readme says it does" do
      grandparent = Node.create(:name => 'Grandparent')
      parent = grandparent.children.create(:name => 'Parent')
      child1 = Node.create(:name => 'First Child', :parent => parent)
      child2 = Node.new(:name => 'Second Child')
      parent.children << child2
      child3 = Node.new(:name => 'Third Child')
      parent.add_child child3
      grandparent.self_and_descendants.collect(&:name).should ==
        ["Grandparent", "Parent", "First Child", "Second Child", "Third Child"]
      child1.ancestry_path.should ==
        ["Grandparent", "Parent", "First Child"]
      child3.ancestry_path.should ==
        ["Grandparent", "Parent", "Third Child"]
      d = Node.find_or_create_by_path %w(a b c d)
      h = Node.find_or_create_by_path %w(e f g h)
      e = h.root
      d.add_child(e) # "d.children << e" would work too, of course
      h.ancestry_path.should == %w(a b c d e f g h)
    end

  end

end

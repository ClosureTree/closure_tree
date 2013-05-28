require 'spec_helper'

shared_examples_for "Tag (without fixtures)" do

  let (:tag_class) {described_class}
  let (:tag_hierarchy_class) {described_class.hierarchy_class}

  it "has correct accessible_attributes" do

    tag_class.accessible_attributes.to_a.should =~ %w(parent name)
  end unless ActiveRecord::VERSION::MAJOR == 4

  describe "empty db" do

    def nuke_db
      tag_hierarchy_class.delete_all
      tag_class.delete_all
    end

    before :each do
      nuke_db
    end

    context "empty db" do
      it "should return no entities" do
        tag_class.roots.should be_empty
        tag_class.leaves.should be_empty
      end
    end

    context "1 tag db" do
      it "should return the only entity as a root and leaf" do
        a = tag_class.create!(:name => "a")
        tag_class.roots.should == [a]
        tag_class.leaves.should == [a]
      end
    end

    context "2 tag db" do
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
      puts grandparent.self_and_descendants.to_sql
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

    context "roots" do
      it "sorts alphabetically" do
        expected = ("a".."z").to_a
        expected.shuffle.each { |ea| tag_class.create!(:name => ea) }
        tag_class.roots.collect { |ea| ea.name }.should == expected
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

      it "should find or create by path" do
        # class method:
        grandparent = tag_class.find_or_create_by_path(%w{grandparent})
        grandparent.should == @grandparent
        child = tag_class.find_or_create_by_path(%w{grandparent parent child})
        child.should == @child
        tag_class.find_or_create_by_path(%w{events anniversary}).ancestry_path.should == %w{events anniversary}
        a = tag_class.find_or_create_by_path(%w{a})
        a.ancestry_path.should == %w{a}
        # instance method:
        a.find_or_create_by_path(%w{b c}).ancestry_path.should == %w{a b c}
      end
    end
  end
end

require 'spec_helper'

describe "empty db" do

  before :each do
    ReferralHierarchy.delete_all
    User.delete_all
  end

  context "empty db" do
    it "should return no entities" do
      User.roots.should be_empty
      User.leaves.should be_empty
    end
  end

  context "1 user db" do
    it "should return the only entity as a root and leaf" do
      a = User.create!(:email => "me@domain.com")
      User.roots.should == [a]
      User.leaves.should == [a]
    end
  end

  context "2 user db" do
    it "should return a simple root and leaf" do
      root = User.create!(:email => "first@t.co")
      leaf = root.children.create!(:email => "second@t.co")
      User.roots.should == [root]
      User.leaves.should == [leaf]
    end
  end

  context "3 User collection.create db" do
    before :each do
      @root = User.create! :email => "poppy@t.co"
      @mid = @root.children.create! :email => "matt@t.co"
      @leaf = @mid.children.create! :email => "james@t.co"
      @root_id = @root.id
    end

    it "should create all Users" do
      User.all.should =~ [@root, @mid, @leaf]
    end

    it "should return a root and leaf without middle User" do
      User.roots.should == [@root]
      User.leaves.should == [@leaf]
    end

    it "should delete leaves" do
      User.leaves.destroy_all
      User.roots.should == [@root] # untouched
      User.leaves.should == [@mid]
    end

    it "should delete roots and maintain hierarchies" do
      User.roots.destroy_all
      assert_mid_and_leaf_remain
    end

    it "should root all children" do
      @root.destroy
      assert_mid_and_leaf_remain
    end

    def assert_mid_and_leaf_remain
      ReferralHierarchy.find_all_by_ancestor_id(@root_id).should be_empty
      ReferralHierarchy.find_all_by_descendant_id(@root_id).should be_empty
      @mid.ancestry_path.should == %w{matt@t.co}
      @leaf.ancestry_path.should == %w{matt@t.co james@t.co}
      @mid.self_and_descendants.should =~ [@mid, @leaf]
      User.roots.should == [@mid]
      User.leaves.should == [@leaf]
    end
  end

  it "supports users with contracts" do
    u = User.find_or_create_by_path(%w(a@t.co b@t.co c@t.co))
    u.descendant_ids.should == []
    u.ancestor_ids.should == [u.parent.id, u.root.id]
    u.root.descendant_ids.should == [u.parent.id, u.id]
    u.root.ancestor_ids.should == []
    c1 = u.contracts.create!
    c2 = u.parent.contracts.create!
    u.root.indirect_contracts.to_a.should =~ [c1, c2]
  end

  it "supports << on shallow unsaved hierarchies" do
    a = User.new(:email => "a")
    b = User.new(:email => "b")
    a.children << b
    a.save
    User.roots.should == [a]
    User.leaves.should == [b]
    b.ancestry_path.should == %w(a b)
  end

  it "supports << on deep unsaved hierarchies" do
    a = User.new(:email => "a")
    b1 = User.new(:email => "b1")
    a.children << b1
    b2 = User.new(:email => "b2")
    a.children << b2
    c1 = User.new(:email => "c1")
    b2.children << c1
    c2 = User.new(:email => "c2")
    b2.children << c2
    d = User.new(:email => "d")
    c2.children << d

    a.save
    User.roots.should == [a]
    User.leaves.should =~ [b1, c1, d]
    d.ancestry_path.should == %w(a b2 c2 d)
  end

  it "supports siblings" do
    User._ct.order_option?.should be_false
    a = User.create(:email => "a")
    b1 = a.children.create(:email => "b1")
    b2 = a.children.create(:email => "b2")
    b3 = a.children.create(:email => "b3")
    a.siblings.should be_empty
    b1.siblings.should =~ [b2, b3]
  end

  context "when a user is not yet saved" do
    it "supports siblings" do
      User._ct.order_option?.should be_false
      a = User.create(:email => "a")
      b1 = a.children.new(:email => "b1")
      b2 = a.children.create(:email => "b2")
      b3 = a.children.create(:email => "b3")
      a.siblings.should be_empty
      b1.siblings.should =~ [b2, b3]
    end
  end

  it "properly nullifies descendents" do
    c = User.find_or_create_by_path %w(a b c)
    b = c.parent
    c.root.destroy
    b.reload.should be_root
    b.child_ids.should == [c.id]
  end

  context "roots" do
    it "works on models without ordering" do
      expected = ("a".."z").to_a
      expected.shuffle.each do |ea|
        User.create! do |u|
          u.email = ea
        end
      end
      User.roots.collect { |ea| ea.email }.sort.should == expected
    end
  end
end

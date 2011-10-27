require 'spec_helper'

describe "empty db" do

  before :each do
    User.delete_all
    ReferralHierarchy.delete_all
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
  end
end

def assert_mid_and_leaf_remain
  @mid.ancestry_path.should == %w{matt@t.co}
  @leaf.ancestry_path.should == %w{matt@t.co james@t.co}
  @mid.self_and_descendants.should =~ [@mid, @leaf]
  User.roots.should == [@mid]
  User.leaves.should == [@leaf]
end

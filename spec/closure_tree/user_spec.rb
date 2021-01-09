require 'spec_helper'

RSpec.describe "empty db" do

  context "empty db" do
    it "should return no entities" do
      expect(User.roots).to be_empty
      expect(User.leaves).to be_empty
    end
  end

  context "1 user db" do
    it "should return the only entity as a root and leaf" do
      a = User.create!(:email => "me@domain.com")
      expect(User.roots).to eq([a])
      expect(User.leaves).to eq([a])
    end
  end

  context "2 user db" do
    it "should return a simple root and leaf" do
      root = User.create!(:email => "first@t.co")
      leaf = root.children.create!(:email => "second@t.co")
      expect(User.roots).to eq([root])
      expect(User.leaves).to eq([leaf])
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
      expect(User.all.to_a).to match_array([@root, @mid, @leaf])
    end

    it 'orders self_and_ancestor_ids nearest generation first' do
      expect(@leaf.self_and_ancestor_ids).to eq([@leaf.id, @mid.id, @root.id])
    end

    it 'orders self_and_descendant_ids nearest generation first' do
      expect(@root.self_and_descendant_ids).to eq([@root.id, @mid.id, @leaf.id])
    end

    it "should have children" do
      expect(@root.children.to_a).to eq([@mid])
      expect(@mid.children.to_a).to eq([@leaf])
      expect(@leaf.children.to_a).to eq([])
    end

    it "roots should have children" do
      expect(User.roots.first.children.to_a).to match_array([@mid])
    end

    it "should return a root and leaf without middle User" do
      expect(User.roots.to_a).to eq([@root])
      expect(User.leaves.to_a).to eq([@leaf])
    end

    it "should delete leaves" do
      User.leaves.destroy_all
      expect(User.roots.to_a).to eq([@root]) # untouched
      expect(User.leaves.to_a).to eq([@mid])
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
      expect(ReferralHierarchy.where(:ancestor_id => @root_id)).to be_empty
      expect(ReferralHierarchy.where(:descendant_id => @root_id)).to be_empty
      expect(@mid.ancestry_path).to eq(%w{matt@t.co})
      expect(@leaf.ancestry_path).to eq(%w{matt@t.co james@t.co})
      expect(@mid.self_and_descendants.to_a).to match_array([@mid, @leaf])
      expect(User.roots).to eq([@mid])
      expect(User.leaves).to eq([@leaf])
    end
  end

  it "supports users with contracts" do
    u = User.find_or_create_by_path(%w(a@t.co b@t.co c@t.co))
    expect(u.descendant_ids).to eq([])
    expect(u.ancestor_ids).to eq([u.parent.id, u.root.id])
    expect(u.self_and_ancestor_ids).to eq([u.id, u.parent.id, u.root.id])
    expect(u.root.descendant_ids).to eq([u.parent.id, u.id])
    expect(u.root.ancestor_ids).to eq([])
    expect(u.root.self_and_ancestor_ids).to eq([u.root.id])
    c1 = u.contracts.create!
    c2 = u.parent.contracts.create!
    expect(u.root.indirect_contracts.to_a).to match_array([c1, c2])
  end

  it "supports << on shallow unsaved hierarchies" do
    a = User.new(:email => "a")
    b = User.new(:email => "b")
    a.children << b
    a.save
    expect(User.roots).to eq([a])
    expect(User.leaves).to eq([b])
    expect(b.ancestry_path).to eq(%w(a b))
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
    expect(User.roots.to_a).to eq([a])
    expect(User.leaves.to_a).to match_array([b1, c1, d])
    expect(d.ancestry_path).to eq(%w(a b2 c2 d))
  end

  it "supports siblings" do
    expect(User._ct.order_option?).to be_falsey
    a = User.create(:email => "a")
    b1 = a.children.create(:email => "b1")
    b2 = a.children.create(:email => "b2")
    b3 = a.children.create(:email => "b3")
    expect(a.siblings).to be_empty
    expect(b1.siblings.to_a).to match_array([b2, b3])
  end

  context "when a user is not yet saved" do
    it "supports siblings" do
      expect(User._ct.order_option?).to be_falsey
      a = User.create(:email => "a")
      b1 = a.children.new(:email => "b1")
      b2 = a.children.create(:email => "b2")
      b3 = a.children.create(:email => "b3")
      expect(a.siblings).to be_empty
      expect(b1.siblings.to_a).to match_array([b2, b3])
    end
  end

  it "properly nullifies descendents" do
    c = User.find_or_create_by_path %w(a b c)
    b = c.parent
    c.root.destroy
    expect(b.reload).to be_root
    expect(b.child_ids).to eq([c.id])
  end

  context "roots" do
    it "works on models without ordering" do
      expected = ("a".."z").to_a
      expected.shuffle.each do |ea|
        User.create! do |u|
          u.email = ea
        end
      end
      expect(User.roots.collect { |ea| ea.email }.sort).to eq(expected)
    end
  end
end

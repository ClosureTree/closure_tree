# frozen_string_literal: true

require "test_helper"

describe "empty db" do
  describe "empty db" do
    it "should return no entities" do
      assert User.roots.empty?
      assert User.leaves.empty?
    end
  end

  describe "1 user db" do
    it "should return the only entity as a root and leaf" do
      a = User.create!(email: "me@domain.com")
      assert_equal [a], User.roots
      assert_equal [a], User.leaves
    end
  end

  describe "2 user db" do
    it "should return a simple root and leaf" do
      root = User.create!(email: "first@t.co")
      leaf = root.children.create!(email: "second@t.co")
      assert_equal [root], User.roots
      assert_equal [leaf], User.leaves
    end
  end

  describe "3 User collection.create db" do
    before do
      @root = User.create! email: "poppy@t.co"
      @mid = @root.children.create! email: "matt@t.co"
      @leaf = @mid.children.create! email: "james@t.co"
      @root_id = @root.id
    end

    it "should create all Users" do
      assert_equal [@root, @mid, @leaf], User.all.to_a.sort
    end

    it "orders self_and_ancestor_ids nearest generation first" do
      assert_equal [@leaf.id, @mid.id, @root.id], @leaf.self_and_ancestor_ids
    end

    it "orders self_and_descendant_ids nearest generation first" do
      assert_equal [@root.id, @mid.id, @leaf.id], @root.self_and_descendant_ids
    end

    it "should have children" do
      assert_equal [@mid], @root.children.to_a
      assert_equal [@leaf], @mid.children.to_a
      assert_equal [], @leaf.children.to_a
    end

    it "roots should have children" do
      assert_equal [@mid], User.roots.first.children.to_a
    end

    it "should return a root and leaf without middle User" do
      assert_equal [@root], User.roots.to_a
      assert_equal [@leaf], User.leaves.to_a
    end

    it "should delete leaves" do
      User.leaves.destroy_all
      assert_equal [@root], User.roots.to_a # untouched
      assert_equal [@mid], User.leaves.to_a
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
      assert ReferralHierarchy.where(ancestor_id: @root_id).empty?
      assert ReferralHierarchy.where(descendant_id: @root_id).empty?
      assert_equal %w[matt@t.co], @mid.ancestry_path
      assert_equal %w[matt@t.co james@t.co], @leaf.ancestry_path
      assert_equal [@mid, @leaf].sort, @mid.self_and_descendants.to_a.sort
      assert_equal [@mid], User.roots
      assert_equal [@leaf], User.leaves
    end
  end

  it "supports users with contracts" do
    u = User.find_or_create_by_path(%w[a@t.co b@t.co c@t.co])
    assert_equal [], u.descendant_ids
    assert_equal [u.parent.id, u.root.id], u.ancestor_ids
    assert_equal [u.id, u.parent.id, u.root.id], u.self_and_ancestor_ids
    assert_equal [u.parent.id, u.id], u.root.descendant_ids
    assert_equal [], u.root.ancestor_ids
    assert_equal [u.root.id], u.root.self_and_ancestor_ids
    c1 = u.contracts.create!
    c2 = u.parent.contracts.create!
    assert_equal [c1, c2].sort, u.root.indirect_contracts.to_a.sort
  end

  it "supports << on shallow unsaved hierarchies" do
    a = User.new(email: "a")
    b = User.new(email: "b")
    a.children << b
    a.save
    assert_equal [a], User.roots
    assert_equal [b], User.leaves
    assert_equal %w[a b], b.ancestry_path
  end

  it "supports << on deep unsaved hierarchies" do
    a = User.new(email: "a")
    b1 = User.new(email: "b1")
    a.children << b1
    b2 = User.new(email: "b2")
    a.children << b2
    c1 = User.new(email: "c1")
    b2.children << c1
    c2 = User.new(email: "c2")
    b2.children << c2
    d = User.new(email: "d")
    c2.children << d

    a.save
    assert_equal [a], User.roots.to_a
    assert_equal [b1, c1, d].sort, User.leaves.to_a.sort
    assert_equal %w[a b2 c2 d], d.ancestry_path
  end

  it "supports siblings" do
    refute User._ct.order_option?
    a = User.create(email: "a")
    b1 = a.children.create(email: "b1")
    b2 = a.children.create(email: "b2")
    b3 = a.children.create(email: "b3")
    assert a.siblings.empty?
    assert_equal [b2, b3].sort, b1.siblings.to_a.sort
  end

  describe "when a user is not yet saved" do
    it "supports siblings" do
      refute User._ct.order_option?
      a = User.create(email: "a")
      b1 = a.children.new(email: "b1")
      b2 = a.children.create(email: "b2")
      b3 = a.children.create(email: "b3")
      assert a.siblings.empty?
      assert_equal [b2, b3].sort, b1.siblings.to_a.sort
    end
  end

  it "properly nullifies descendents" do
    c = User.find_or_create_by_path %w[a b c]
    b = c.parent
    c.root.destroy
    assert b.reload.root?
    assert_equal [c.id], b.child_ids
  end

  describe "roots" do
    it "works on models without ordering" do
      expected = ("a".."z").to_a
      expected.shuffle.each do |ea|
        User.create! do |u|
          u.email = ea
        end
      end
      assert_equal(expected, User.roots.collect { |ea| ea.email }.sort)
    end
  end
end

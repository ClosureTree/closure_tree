require 'spec_helper'

module HashTreeScopeValidator
  def build_hash_tree(tree_scope, root = nil)
    @tree_hash_scope = tree_scope
    super
  end

  def tree_hash_scope
    @tree_hash_scope
  end
end

describe Tag do

  def assert_scope_has_no_dupes(scope)
    scope.to_a.should == scope.to_a.uniq
  end

  it "builds hash_trees properly" do
    class Tag
      extend HashTreeScopeValidator
    end

    b = Tag.find_or_create_by_path %w(a b)
    a = b.parent
    b2 = Tag.find_or_create_by_path %w(a b2)
    d1 = b.find_or_create_by_path %w(c1 d1)
    c1 = d1.parent
    d2 = b.find_or_create_by_path %w(c2 d2)
    c2 = d2.parent
    Tag.hash_tree(:limit_depth => 0).should == {}
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    Tag.hash_tree(:limit_depth => 1).should == {a => {}}
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    Tag.hash_tree(:limit_depth => 2).should == {a => {b => {}, b2 => {}}}
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    tree = {a => {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}, b2 => {}}}
    Tag.hash_tree(:limit_depth => 4).should == tree
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    Tag.hash_tree.should == tree
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    b.hash_tree(:limit_depth => 0).should == {}
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    b.hash_tree(:limit_depth => 1).should == {b => {}}
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    b.hash_tree(:limit_depth => 2).should == {b => {c1 => {}, c2 => {}}}
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    b_tree = {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}}
    b.hash_tree(:limit_depth => 3).should == b_tree
    assert_scope_has_no_dupes(Tag.tree_hash_scope)

    b.hash_tree.should == b_tree
    assert_scope_has_no_dupes(Tag.tree_hash_scope)
  end
end

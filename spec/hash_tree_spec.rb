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

  def hash_tree(target, *args)
    target.send(:hash_tree, *args).
      tap { |ea| a = Tag.tree_hash_scope.to_a ; a.should == a.uniq }
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
    hash_tree(Tag, :limit_depth => 0).should == {}

    hash_tree(Tag, :limit_depth => 1).should == {a => {}}

    hash_tree(Tag, :limit_depth => 2).should == {a => {b => {}, b2 => {}}}

    tree = {a => {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}, b2 => {}}}
    hash_tree(Tag, :limit_depth => 4).should == tree

    hash_tree(Tag).should == tree

    hash_tree(b, :limit_depth => 0).should == {}

    hash_tree(b, :limit_depth => 1).should == {b => {}}

    hash_tree(b, :limit_depth => 2).should == {b => {c1 => {}, c2 => {}}}

    b_tree = {b => {c1 => {d1 => {}}, c2 => {d2 => {}}}}
    hash_tree(b, :limit_depth => 3).should == b_tree

    hash_tree(b).should == b_tree
  end
end

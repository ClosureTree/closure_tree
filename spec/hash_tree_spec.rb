require 'spec_helper'

describe Tag do

  before :each do
    @b = Tag.find_or_create_by_path %w(a b)
    @a = @b.parent
    @b2 = Tag.find_or_create_by_path %w(a b2)
    @d1 = @b.find_or_create_by_path %w(c1 d1)
    @c1 = @d1.parent
    @d2 = @b.find_or_create_by_path %w(c2 d2)
    @c2 = @d2.parent
    @full_tree = {@a => {@b => {@c1 => {@d1 => {}}, @c2 => {@d2 => {}}}, @b2 => {}}}
  end

  context "#hash_tree" do
    it "returns {} for depth 0" do
      Tag.hash_tree(:limit_depth => 0).should == {}
    end
    it "limit_depth 1" do
      Tag.hash_tree(:limit_depth => 1).should == {@a => {}}
    end
    it "limit_depth 2" do
      Tag.hash_tree(:limit_depth => 2).should == {@a => {@b => {}, @b2 => {}}}
    end
    it "limit_depth 3" do
      Tag.hash_tree(:limit_depth => 3).should == {@a => {@b => {@c1 => {}, @c2 => {}}, @b2 => {}}}
    end
    it "limit_depth 4" do
      Tag.hash_tree(:limit_depth => 4).should == @full_tree
    end
    it "no limit holdum" do
      Tag.hash_tree.should == @full_tree
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
        assert_no_dupes(Tag.hash_tree_scope(ea))
      end
    end
    it "no limit holdum" do
      assert_no_dupes(Tag.hash_tree_scope)
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

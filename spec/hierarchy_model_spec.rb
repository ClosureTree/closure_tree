require 'spec_helper'

describe "The generated hierarchy model" do
  let(:model)      { TagHierarchy.new }
  let(:table_name) do
    ActiveRecord::Base.table_name_prefix +
    "tag_hierarchies" +
    ActiveRecord::Base.table_name_suffix
  end

  it { model.class.table_name.should eq(table_name) }

  describe "attributes" do
    it { model.should respond_to(:ancestor_id) }
    it { model.should respond_to(:descendant_id) }
    it { model.should respond_to(:generations) }
  end

  describe "associations" do
    it { model.should respond_to(:ancestor) }
    it { model.should respond_to(:descendant) }

    let(:tag)       { Tag.create! :name => "test" }
    let(:hierarchy) { TagHierarchy.find_by_ancestor_id(tag.id) }

    it { hierarchy.ancestor.should eq(tag) }
    it { hierarchy.descendant.should eq(tag) }
  end

  describe "equality" do
    it { model.should eq(TagHierarchy.new) }

    it "evaluates to true for different instances with the same attributes" do
      model1 = TagHierarchy.new(:ancestor_id => 1, :descendant_id => 2)
      model2 = TagHierarchy.new(:ancestor_id => 1, :descendant_id => 2)
      model1.should eq(model2)
    end
  end

  describe "HierarchyModel.depths" do
    let(:results) { TagHierarchy.depths }

    def node(tag)
      results.find{ |r| r.node_id == tag.id }
    end

    before do
      TagHierarchy.delete_all
      Tag.delete_all

      @b  = Tag.find_or_create_by_path %w(a b)
      @a  = @b.parent
      @b2 = Tag.find_or_create_by_path %w(a b2)
      @d1 = @b.find_or_create_by_path %w(c1 d1)
      @c1 = @d1.parent
      @d2 = @b.find_or_create_by_path %w(c2 d2)
      @c2 = @d2.parent
    end

    it "returns one row for each descendant" do
      results.all.size.should eq(7)
    end

    it "returns the correct depth (max generations)" do
      node(@a).depth.should eq(0)

      node(@b).depth.should eq(1)
      node(@b2).depth.should eq(1)

      node(@c1).depth.should eq(2)
      node(@c2).depth.should eq(2)

      node(@d1).depth.should eq(3)
      node(@d2).depth.should eq(3)
    end

    describe "with limit" do
      it "<0 returns nothing" do
        results = TagHierarchy.depths(:limit => -1)
        results.all.size.should eq(0)
      end

      it "0 returns hierarchy for `a`" do
        results = TagHierarchy.depths(:limit => 0)
        results.all.size.should eq(1)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
      end

      it "1 returns hierarchies for `a`, `b`, `b2`" do
        results = TagHierarchy.depths(:limit => 1)
        results.all.size.should eq(3)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
        result_ids.should include(@b.id)
        result_ids.should include(@b2.id)
        result_ids.should_not include(@c1.id)
        result_ids.should_not include(@c2.id)
        result_ids.should_not include(@d1.id)
        result_ids.should_not include(@d2.id)
      end

      it "2 returns hierarchies for `a`, `b`, `b2`, `c1`, `c2`" do
        results = TagHierarchy.depths(:limit => 2)
        results.all.size.should eq(5)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
        result_ids.should include(@b.id)
        result_ids.should include(@b2.id)
        result_ids.should include(@c1.id)
        result_ids.should include(@c2.id)
        result_ids.should_not include(@d1.id)
        result_ids.should_not include(@d2.id)
      end

      it "3 returns hierarchies for all tags" do
        results = TagHierarchy.depths(:limit => 3)
        results.all.size.should eq(7)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
        result_ids.should include(@b.id)
        result_ids.should include(@b2.id)
        result_ids.should include(@c1.id)
        result_ids.should include(@c2.id)
        result_ids.should include(@d1.id)
        result_ids.should include(@d2.id)
      end

      it "nil returns all records" do
        results = TagHierarchy.depths(:limit => nil)
        results.all.size.should eq(7)
      end
    end

    describe "with only" do
      it "0 returns hierarchy for `a`" do
        results = TagHierarchy.depths(:only => 0)
        results.all.size.should eq(1)
        results.map(&:node_id).should include(@a.id)
      end

      it "1 returns hierarchies for `b`, `b2`" do
        results = TagHierarchy.depths(:only => 1)
        results.all.size.should eq(2)

        result_ids = results.map(&:node_id)
        result_ids.should_not include(@a.id)
        result_ids.should include(@b.id)
        result_ids.should include(@b2.id)
        result_ids.should_not include(@c1.id)
        result_ids.should_not include(@c2.id)
        result_ids.should_not include(@d1.id)
        result_ids.should_not include(@d2.id)
      end

      it "2 returns hierarchies for `c1`, `c2`" do
        results = TagHierarchy.depths(:only => 2)
        results.all.size.should eq(2)

        result_ids = results.map(&:node_id)
        result_ids.should_not include(@a.id)
        result_ids.should_not include(@b.id)
        result_ids.should_not include(@b2.id)
        result_ids.should include(@c1.id)
        result_ids.should include(@c2.id)
        result_ids.should_not include(@d1.id)
        result_ids.should_not include(@d2.id)
      end

      it "3 returns hierarchies for `d1`, `d2`" do
        results = TagHierarchy.depths(:only => 3)
        results.all.size.should eq(2)

        result_ids = results.map(&:node_id)
        result_ids.should_not include(@a.id)
        result_ids.should_not include(@b.id)
        result_ids.should_not include(@b2.id)
        result_ids.should_not include(@c1.id)
        result_ids.should_not include(@c2.id)
        result_ids.should include(@d1.id)
        result_ids.should include(@d2.id)
      end

      it "nil returns all records" do
        results = TagHierarchy.depths(:only => nil)
        results.all.size.should eq(7)
      end
    end
  end

  describe "HierarchyModel.heights" do
    let(:results) { TagHierarchy.heights }

    def node(tag)
      results.find{ |r| r.node_id == tag.id }
    end

    before do
      TagHierarchy.delete_all
      Tag.delete_all

      @b  = Tag.find_or_create_by_path %w(a b)
      @a  = @b.parent
      @b2 = Tag.find_or_create_by_path %w(a b2)
      @d1 = @b.find_or_create_by_path %w(c1 d1)
      @c1 = @d1.parent
      @d2 = @b.find_or_create_by_path %w(c2 d2)
      @c2 = @d2.parent
    end

    it "returns one row for each ancestor" do
      results.all.size.should eq(7)
    end

    it "returns the correct height (max generations)" do
      node(@a).height.should eq(3)

      node(@b).height.should eq(2)

      node(@c1).height.should eq(1)
      node(@c2).height.should eq(1)

      # no descendents
      node(@b2).height.should eq(0)
      node(@d1).height.should eq(0)
      node(@d2).height.should eq(0)
    end

    describe "with limit" do
      it ">MAX returns nothing" do
        results = TagHierarchy.heights(:limit => 5)
        results.all.size.should eq(0)
      end

      it "3 returns hierarchy for `a`" do
        results = TagHierarchy.heights(:limit => 3)
        results.all.size.should eq(1)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
      end

      it "2 returns hierarchies for `a`, `b`" do
        results = TagHierarchy.heights(:limit => 2)
        results.all.size.should eq(2)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
        result_ids.should include(@b.id)
        result_ids.should_not include(@b2.id)
        result_ids.should_not include(@c1.id)
        result_ids.should_not include(@c2.id)
        result_ids.should_not include(@d1.id)
        result_ids.should_not include(@d2.id)
      end

      it "1 returns hierarchies for `a`, `b`, `c1`, `c2`" do
        results = TagHierarchy.heights(:limit => 1)
        results.all.size.should eq(4)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
        result_ids.should include(@b.id)
        result_ids.should_not include(@b2.id)
        result_ids.should include(@c1.id)
        result_ids.should include(@c2.id)
        result_ids.should_not include(@d1.id)
        result_ids.should_not include(@d2.id)
      end

      it "0 returns hierarchies for all tags" do
        results = TagHierarchy.heights(:limit => 0)
        results.all.size.should eq(7)

        result_ids = results.map(&:node_id)
        result_ids.should include(@a.id)
        result_ids.should include(@b.id)
        result_ids.should include(@b2.id)
        result_ids.should include(@c1.id)
        result_ids.should include(@c2.id)
        result_ids.should include(@d1.id)
        result_ids.should include(@d2.id)
      end

      it "nil returns all records" do
        results = TagHierarchy.heights(:limit => nil)
        results.all.size.should eq(7)
      end
    end

    describe "with only" do
      it "3 returns hierarchy for `a`" do
        results = TagHierarchy.heights(:only => 3)
        results.all.size.should eq(1)
        results.map(&:node_id).should include(@a.id)
      end

      it "2 returns hierarchies for `b`" do
        results = TagHierarchy.heights(:only => 2)
        results.all.size.should eq(1)

        result_ids = results.map(&:node_id)
        result_ids.should include(@b.id)
      end

      it "1 returns hierarchies for `c1`, `c2`" do
        results = TagHierarchy.heights(:only => 1)
        results.all.size.should eq(2)

        result_ids = results.map(&:node_id)
        result_ids.should_not include(@a.id)
        result_ids.should_not include(@b.id)
        result_ids.should_not include(@b2.id)
        result_ids.should include(@c1.id)
        result_ids.should include(@c2.id)
        result_ids.should_not include(@d1.id)
        result_ids.should_not include(@d2.id)
      end

      it "0 returns hierarchies for `b2`, `d1`, `d2`" do
        results = TagHierarchy.heights(:only => 0)
        results.all.size.should eq(3)

        result_ids = results.map(&:node_id)
        result_ids.should_not include(@a.id)
        result_ids.should_not include(@b.id)
        result_ids.should include(@b2.id)
        result_ids.should_not include(@c1.id)
        result_ids.should_not include(@c2.id)
        result_ids.should include(@d1.id)
        result_ids.should include(@d2.id)
      end

      it "nil returns all records" do
        results = TagHierarchy.heights(:only => nil)
        results.all.size.should eq(7)
      end
    end
  end
end

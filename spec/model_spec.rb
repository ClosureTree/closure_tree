require 'spec_helper'

describe "The model" do
  let(:model) { Tag.new }

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

  describe "Model.with_depths" do
    let(:results) { Tag.with_depths.order("depths.depth") }

    it "returns one row for each tag" do
      results.all.size.should eq(7)
      results.first.depth.should eq(0)
    end

    describe "with limit" do
      it "<0 returns nothing" do
        results = Tag.with_depths(:limit => -1)
        results.all.size.should eq(0)
      end

      it "0 returns `a`" do
        results = Tag.with_depths(:limit => 0)
        results.all.size.should eq(1)
        results.should include(@a)
      end

      it "1 returns `a`, `b`, `b2`" do
        results = Tag.with_depths(:limit => 1)
        results.all.size.should eq(3)

        results.should include(@a)
        results.should include(@b)
        results.should include(@b2)
        results.should_not include(@c1)
        results.should_not include(@c2)
        results.should_not include(@d1)
        results.should_not include(@d2)
      end

      it "2 returns `a`, `b`, `b2`, `c1`, `c2`" do
        results = Tag.with_depths(:limit => 2)
        results.all.size.should eq(5)

        results.should include(@a)
        results.should include(@b)
        results.should include(@b2)
        results.should include(@c1)
        results.should include(@c2)
        results.should_not include(@d1)
        results.should_not include(@d2)
      end

      it "3 returns all tags" do
        results = Tag.with_depths(:limit => 3)
        results.all.size.should eq(7)

        results.should include(@a)
        results.should include(@b)
        results.should include(@b2)
        results.should include(@c1)
        results.should include(@c2)
        results.should include(@d1)
        results.should include(@d2)
      end

      it "nil returns all records" do
        results = Tag.with_depths(:limit => nil)
        results.all.size.should eq(7)
      end
    end

    describe "with generation_level" do
      it "0 returns `a`" do
        results = Tag.with_depths(:only => 0)
        results.all.size.should eq(1)
        results.should include(@a)
      end

      it "1 returns `b`, `b2`" do
        results = Tag.with_depths(:only => 1)
        results.all.size.should eq(2)

        results.should_not include(@a)
        results.should include(@b)
        results.should include(@b2)
        results.should_not include(@c1)
        results.should_not include(@c2)
        results.should_not include(@d1)
        results.should_not include(@d2)
      end

      it "2 returns `c1`, `c2`" do
        results = Tag.with_depths(:only => 2)
        results.all.size.should eq(2)

        results.should_not include(@a)
        results.should_not include(@b)
        results.should_not include(@b2)
        results.should include(@c1)
        results.should include(@c2)
        results.should_not include(@d1)
        results.should_not include(@d2)
      end

      it "3 returns `d1`, `d2`" do
        results = Tag.with_depths(:only => 3)
        results.all.size.should eq(2)

        results.should_not include(@a)
        results.should_not include(@b)
        results.should_not include(@b2)
        results.should_not include(@c1)
        results.should_not include(@c2)
        results.should include(@d1)
        results.should include(@d2)
      end

      it "nil returns all records" do
        results = Tag.with_depths(:only => nil)
        results.all.size.should eq(7)
      end
    end
  end

  describe "Model.with_heights" do
    let(:results) { Tag.with_heights.order("heights.height DESC") }

    it "returns one row for each tag" do
      results.all.size.should eq(7)
      results.first.height.should eq(3)
    end

    describe "with limit" do
      it ">MAX returns nothing" do
        results = Tag.with_heights(:limit => 5)
        results.all.size.should eq(0)
      end

      it "3 returns `a`" do
        results = Tag.with_heights(:limit => 3)
        results.all.size.should eq(1)
        results.should include(@a)
      end

      it "2 returns `a`, `b`" do
        results = Tag.with_heights(:limit => 2)
        results.all.size.should eq(2)

        results.should include(@a)
        results.should include(@b)
        results.should_not include(@b2)
        results.should_not include(@c1)
        results.should_not include(@c2)
        results.should_not include(@d1)
        results.should_not include(@d2)
      end

      it "1 returns `a`, `b`, `c1`, `c2`" do
        results = Tag.with_heights(:limit => 1)
        results.all.size.should eq(4)

        results.should include(@a)
        results.should include(@b)
        results.should_not include(@b2)
        results.should include(@c1)
        results.should include(@c2)
        results.should_not include(@d1)
        results.should_not include(@d2)
      end

      it "0 returns all tags" do
        results = Tag.with_heights(:limit => 0)
        results.all.size.should eq(7)

        results.should include(@a)
        results.should include(@b)
        results.should include(@b2)
        results.should include(@c1)
        results.should include(@c2)
        results.should include(@d1)
        results.should include(@d2)
      end

      it "nil returns all records" do
        results = Tag.with_heights(:limit => nil)
        results.all.size.should eq(7)
      end
    end

    describe "with generation_level" do
      it "3 returns `a`" do
        results = Tag.with_heights(:only => 3)
        results.all.size.should eq(1)
        results.should include(@a)
      end

      it "2 returns `b`" do
        results = Tag.with_heights(:only => 2)
        results.all.size.should eq(1)
        results.should include(@b)
      end

      it "1 returns `c1`, `c2`" do
        results = Tag.with_heights(:only => 1)
        results.all.size.should eq(2)

        results.should_not include(@a)
        results.should_not include(@b)
        results.should_not include(@b2)
        results.should include(@c1)
        results.should include(@c2)
        results.should_not include(@d1)
        results.should_not include(@d2)
      end

      it "0 returns `b2`, `d1`, `d2`" do
        results = Tag.with_heights(:only => 0)
        results.all.size.should eq(3)

        results.should_not include(@a)
        results.should_not include(@b)
        results.should include(@b2)
        results.should_not include(@c1)
        results.should_not include(@c2)
        results.should include(@d1)
        results.should include(@d2)
      end

      it "nil returns all records" do
        results = Tag.with_heights(:only => nil)
        results.all.size.should eq(7)
      end
    end
  end

  # at_depth is an alias for find_all_by_generation
  describe "Model.at_depth" do
    it "returns `b`, `b2`" do
      results = Tag.at_depth(1)
      results.all.size.should eq(2)
      results.should_not include(@a)
      results.should include(@b)
      results.should include(@b2)
    end
  end

  # at_height
  describe "Model.at_height" do
    it "returns `b`" do
      results = Tag.at_height(2)
      results.all.size.should eq(1)
      results.should_not include(@a)
      results.should include(@b)
      results.should_not include(@b2)
    end
  end
end

require 'spec_helper'

describe "The model" do
  let(:model) { Tag.new }

  describe "Model.with_depth" do
    let(:results) { Tag.with_depths }

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
end

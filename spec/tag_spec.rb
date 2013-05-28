require 'spec_helper'
require 'tag_examples'

shared_examples_for "Tag (with fixtures)" do
  describe "Tag (with fixtures)" do

    fixtures :tags

    before :each do
      Tag.rebuild!
      DestroyedTag.delete_all
    end

    context "class injection" do
      it "should build hierarchy classname correctly" do
        Tag.hierarchy_class.to_s.should == "TagHierarchy"
        Tag._ct.hierarchy_class_name.should == "TagHierarchy"
        Tag._ct.short_hierarchy_class_name.should == "TagHierarchy"
      end

      it "should have a correct parent column name" do
        Tag._ct.parent_column_name.should == "parent_id"
      end
    end

    context "roots" do
      it "should find global roots" do
        roots = Tag.roots.to_a
        roots.should be_member(tags(:people))
        roots.should be_member(tags(:events))
        roots.should_not be_member(tags(:child))
        tags(:people).root?.should be_true
        tags(:child).root?.should be_false
      end

      it "should find an instance root" do
        tags(:grandparent).root.should == tags(:grandparent)
        tags(:parent).root.should == tags(:grandparent)
        tags(:child).root.should == tags(:grandparent)
      end
    end

    context "leaves" do
      it "should assemble global leaves" do
        Tag.leaves.size.should > 0
        Tag.leaves.each { |t| t.children.should be_empty, "#{t.name} was returned by leaves but has children: #{t.children}" }
        Tag.leaves.each { |t| t.should be_leaf, "{t.name} was returned by leaves but was not a leaf" }
      end

      it "should assemble instance leaves" do
        tags(:grandparent).leaves.should == [tags(:child)]
        tags(:parent).leaves.should == [tags(:child)]
        tags(:child).leaves.should == [tags(:child)]
      end
    end

    context "adding children" do
      it "should work explicitly" do
        sb = Tag.create!(:name => "Santa Barbara")
        sb.leaf?.should_not be_nil
        tags(:california).add_child sb
        sb.leaf?.should_not be_nil
        validate_city_tag sb
      end

      it "should work implicitly through the collection" do
        eg = Tag.create!(:name => "El Granada")
        eg.leaf?.should_not be_nil
        tags(:california).children << eg
        eg.leaf?.should_not be_nil
        validate_city_tag eg
      end

      it "should fail to create ancestor loops" do
        child = tags(:child)
        parent = child.parent
        child.add_child(parent) # this should fail
        parent.valid?.should be_false
        child.reload.children.should be_empty
        parent.reload.children.should == [child]
      end

      it "should move non-leaves" do
        # This is what the fixture should encode:
        tags(:d2).ancestry_path.should == %w{a1 b2 c2 d2}
        tags(:b1).add_child(tags(:c2))
        tags(:b2).leaf?.should_not be_nil
        tags(:b1).children.include?(tags(:c2)).should be_true
        tags(:d2).reload.ancestry_path.should == %w{a1 b1 c2 d2}
      end

      it "should move leaves" do
        l = Tag.find_or_create_by_path(%w{leaftest branch1 leaf})
        b2 = Tag.find_or_create_by_path(%w{leaftest branch2})
        b2.children << l
        l.ancestry_path.should == %w{leaftest branch2 leaf}
      end

      it "should move roots" do
        l1 = Tag.find_or_create_by_path(%w{roottest1 branch1 leaf1})
        l2 = Tag.find_or_create_by_path(%w{roottest2 branch2 leaf2})
        l1.children << l2.root
        l1.reload.ancestry_path.should == %w{roottest1 branch1 leaf1}
        l2.reload.ancestry_path.should == %w{roottest1 branch1 leaf1 roottest2 branch2 leaf2}
      end

      it "should cascade delete all children" do
        b2 = tags(:b2)
        entities = b2.self_and_descendants.to_a
        names = b2.self_and_descendants.collect { |t| t.name }
        b2.destroy
        entities.each { |e| Tag.find_by_id(e.id).should be_nil }
        DestroyedTag.all.collect { |t| t.name }.should =~ names
      end
    end

    context "injected attributes" do
      it "should compute level correctly" do
        tags(:grandparent).level.should == 0
        tags(:parent).level.should == 1
        tags(:child).level.should == 2
      end

      it "should determine parent correctly" do
        tags(:grandparent).parent.should == nil
        tags(:parent).parent.should == tags(:grandparent)
        tags(:child).parent.should == tags(:parent)
      end

      it "should have a sane children collection" do
        tags(:grandparent).children.include? tags(:parent).should be_true
        tags(:parent).children.include? tags(:child).should be_true
        tags(:child).children.should be_empty
      end

      it "assembles siblings correctly" do
        tags(:b1).siblings.to_a.should =~ [tags(:b2)]
        tags(:a1).siblings.to_a.should =~ (Tag.roots.to_a - [tags(:a1)])
        tags(:a1).self_and_siblings.to_a.should =~ Tag.roots.to_a

        # must be ordered
        tags(:indoor).siblings.to_a.should == [tags(:home), tags(:museum), tags(:outdoor), tags(:united_states)]
        tags(:indoor).self_and_siblings.to_a.should == [tags(:home), tags(:indoor), tags(:museum), tags(:outdoor), tags(:united_states)]
      end

      it "assembles siblings before correctly" do
        tags(:home).siblings_before.to_a.should == []
        tags(:indoor).siblings_before.to_a.should == [tags(:home)]
        tags(:outdoor).siblings_before.to_a.should == [tags(:home), tags(:indoor), tags(:museum)]
        tags(:united_states).siblings_before.to_a.should == [tags(:home), tags(:indoor), tags(:museum), tags(:outdoor)]
      end

      it "assembles siblings after correctly" do
        tags(:indoor).siblings_after.to_a.should == [tags(:museum), tags(:outdoor), tags(:united_states)]
        tags(:outdoor).siblings_after.to_a.should == [tags(:united_states)]
        tags(:united_states).siblings_after.to_a.should == []
      end

      it "assembles ancestors" do
        tags(:child).ancestors.should == [tags(:parent), tags(:grandparent)]
        tags(:child).self_and_ancestors.should == [tags(:child), tags(:parent), tags(:grandparent)]
      end

      it "assembles descendants" do
        tags(:parent).descendants.should == [tags(:child)]
        tags(:parent).self_and_descendants.should == [tags(:parent), tags(:child)]
        tags(:grandparent).descendants.should == [tags(:parent), tags(:child)]
        tags(:grandparent).self_and_descendants.should == [tags(:grandparent), tags(:parent), tags(:child)]
        tags(:grandparent).self_and_descendants.collect { |t| t.name }.join(" > ").should == "grandparent > parent > child"
      end
    end

    def validate_city_tag city
      tags(:california).children.include?(city).should_not be_nil
      city.ancestors.should == [tags(:california), tags(:united_states), tags(:places)]
      city.self_and_ancestors.should == [city, tags(:california), tags(:united_states), tags(:places)]
    end

  end
end

if ActiveRecord::VERSION::MAJOR == 4
  describe Tag do
    it_behaves_like "Tag (without fixtures)"
    it_behaves_like "Tag (with fixtures)"
  end
else
  describe Tag do
    it "should not include ActiveModel::ForbiddenAttributesProtection" do
      if defined?(ActiveModel::ForbiddenAttributesProtection)
        Tag.ancestors.should_not include(ActiveModel::ForbiddenAttributesProtection)
      end
    end
    it_behaves_like "Tag (without fixtures)"
    it_behaves_like "Tag (with fixtures)"
  end

  describe "Tag with AR whitelisted attributes enabled" do
    before(:all) do
      ActiveRecord::Base.attr_accessible(nil) # turn on whitelisted attributes
      ActiveRecord::Base.descendants.each { |ea| ea.reset_column_information }
    end
    it "should not include ActiveModel::ForbiddenAttributesProtection" do
      if defined?(ActiveModel::ForbiddenAttributesProtection)
        Tag.ancestors.should_not include(ActiveModel::ForbiddenAttributesProtection)
      end
    end
    it_behaves_like "Tag (without fixtures)"
    it_behaves_like "Tag (with fixtures)"
  end

# This has to be the last one, because we include strong parameters into Tag
  describe "Tag with strong parameters" do
    before(:all) do
      require 'strong_parameters'
      class Tag
        include ActiveModel::ForbiddenAttributesProtection
      end
    end
    it_behaves_like "Tag (without fixtures)"
    it_behaves_like "Tag (with fixtures)"
  end
end

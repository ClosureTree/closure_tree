require 'spec_helper'

describe "The generated hierarchy model" do
  let(:model) { TagHierarchy.new }

  it { model.class.table_name.should eq("tag_hierarchies") }

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
end

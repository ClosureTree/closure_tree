require 'spec_helper'

def nuke_db
  Label.delete_all
  LabelHierarchy.delete_all
end

describe Label do
  context "Base Label class" do
    it "should find or create by path" do
      # class method:
      c = Label.find_or_create_by_path(%w{grandparent parent child})
      c.ancestry_path.should == %w{grandparent parent child}
      c.name.should == "child"
      c.parent.name.should == "parent"
    end
  end
  context "DateLabel" do

    it "should find or create by path" do
      date = DateLabel.find_or_create_by_path(%w{2011 November 23})
      date.ancestry_path.should == %w{2011 November 23}
      date.parent
      date.self_and_ancestors.each { |ea| ea.class.should == DateLabel }
      date.name.should == "23"
      date.parent.name.should == "November"
    end
  end

  context "DirectoryLabel" do
    it "should find or create by path" do
      dir = DirectoryLabel.find_or_create_by_path(%w{grandparent parent child})
      dir.ancestry_path.should == %w{grandparent parent child}
      dir.name.should == "child"
      dir.parent.name.should == "parent"
      dir.parent.parent.name.should == "grandparent"
      dir.root.name.should == "grandparent"
      dir.id.should_not == Label.find_or_create_by_path(%w{grandparent parent child})
      dir.self_and_ancestors.each { |ea| ea.class.should == DirectoryLabel }
    end
  end

  context "Mixed class tree" do
    it "should support mixed type ancestors" do
      [Label, DateLabel, DirectoryLabel, EventLabel].permutation do |classes|
        nuke_db
        classes.each{|c|c.all.should(be_empty, "class #{c} wasn't cleaned out") }
        names = ('A'..'Z').to_a.first(classes.size)
        instances = classes.collect { |clazz| clazz.new(:name => names.shift) }
        a = instances.first
        a.save!
        a.name.should == "A"
        instances[1..-1].each_with_index do |ea, idx|
          instances[idx].children << ea
        end
        roots = classes.first.roots
        i = instances.shift
        roots.should =~ [i]
        while (!instances.empty?) do
          child = instances.shift
          i.children.should =~ [child]
          i = child
        end
      end
    end
  end
end

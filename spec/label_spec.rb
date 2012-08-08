require 'spec_helper'

def nuke_db
  LabelHierarchy.delete_all
  Label.delete_all
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
        classes.each { |c| c.all.should(be_empty, "class #{c} wasn't cleaned out") }
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

  context "Deterministic siblings sort with custom integer column" do
    nuke_db
    fixtures :labels

    before :each do
      Label.rebuild!
    end

    it "orders siblings_before and siblings_after correctly" do
      labels(:c16).self_and_siblings.to_a.should == [labels(:c16), labels(:c17), labels(:c18), labels(:c19)]
      labels(:c16).siblings_before.to_a.should == []
      labels(:c16).siblings_after.to_a.should == [labels(:c17), labels(:c18), labels(:c19)]
    end

    it "should prepend a node as a sibling of another node" do
      labels(:c16).prepend_sibling(labels(:c17))
      labels(:c16).self_and_siblings.to_a.should == [labels(:c17), labels(:c16), labels(:c18), labels(:c19)]
      labels(:c19).prepend_sibling(labels(:c16))
      labels(:c16).self_and_siblings.to_a.should == [labels(:c17), labels(:c18), labels(:c16), labels(:c19)]
      labels(:c16).siblings_before.to_a.should == [labels(:c17), labels(:c18)]
      labels(:c16).siblings_after.to_a.should == [labels(:c19)]
    end

    it "should prepend a node as a sibling of another node (!update_all)" do
      labels(:c16).prepend_sibling(labels(:c17), false)
      labels(:c16).self_and_siblings.to_a.should == [labels(:c17), labels(:c16), labels(:c18), labels(:c19)]
      labels(:c19).reload.prepend_sibling(labels(:c16).reload, false)
      labels(:c16).self_and_siblings.to_a.should == [labels(:c17), labels(:c18), labels(:c16), labels(:c19)]
      labels(:c16).siblings_before.to_a.should == [labels(:c17), labels(:c18)]
      labels(:c16).siblings_after.to_a.should == [labels(:c19)]
    end

    it "appends a node as a sibling of another node" do
      labels(:c19).append_sibling(labels(:c17))
      labels(:c16).self_and_siblings.to_a.should == [labels(:c16), labels(:c18), labels(:c19), labels(:c17)]
      labels(:c16).append_sibling(labels(:c19))
      labels(:c16).self_and_siblings.to_a.should == [labels(:c16), labels(:c19), labels(:c18), labels(:c17)]
      labels(:c16).siblings_before.to_a.should == []
      labels(:c16).siblings_after.to_a.should == labels(:c16).siblings.to_a
    end

    it "should move a node before another node (update_all)" do
      labels(:c2).ancestry_path.should == %w{a1 b2 c2}
      labels(:b2).prepend_sibling(labels(:c2))
      labels(:c2).ancestry_path.should == %w{a1 c2}
      labels(:c2).self_and_siblings.to_a.should == [labels(:b1), labels(:c2), labels(:b2)]
      labels(:c2).siblings_before.to_a.should == [labels(:b1)]
      labels(:c2).siblings_after.to_a.should == [labels(:b2)]
      labels(:b1).siblings_after.to_a.should == [labels(:c2), labels(:b2)]
    end

    it "should move a node after another node (update_all)" do
      labels(:c2).ancestry_path.should == %w{a1 b2 c2}
      labels(:b2).append_sibling(labels(:c2))
      labels(:c2).ancestry_path.should == %w{a1 c2}
      labels(:c2).self_and_siblings.to_a.should == [labels(:b1), labels(:b2), labels(:c2)]
    end

    it "should move a node before another node" do
      labels(:c2).ancestry_path.should == %w{a1 b2 c2}
      labels(:b2).prepend_sibling(labels(:c2), false)
      labels(:c2).ancestry_path.should == %w{a1 c2}
      labels(:c2).self_and_siblings.to_a.should == [labels(:b1), labels(:c2), labels(:b2)]
    end

    it "should move a node after another node" do
      labels(:c2).ancestry_path.should == %w{a1 b2 c2}
      labels(:b2).append_sibling(labels(:c2), false)
      labels(:c2).ancestry_path.should == %w{a1 c2}
      labels(:c2).self_and_siblings.to_a.should == [labels(:b1), labels(:b2), labels(:c2)]
      labels(:c2).append_sibling(labels(:e2), false)
      labels(:e2).self_and_siblings.to_a.should == [labels(:b1), labels(:b2), labels(:c2), labels(:e2)]
      labels(:a1).self_and_descendants.collect(&:name).should == %w(a1 b1 b2 c2 e2 d2 c1-six c1-seven c1-eight c1-nine)
      labels(:a1).leaves.collect(&:name).should == %w(d2 b2 e2 c1-six c1-seven c1-eight c1-nine)
    end
  end
end

require 'spec_helper'

def delete_all_labels
  LabelHierarchy.delete_all
  Label.delete_all
end

def create_label_tree
  @d1 = Label.find_or_create_by_path %w(a1 b1 c1 d1)
  @c1 = @d1.parent
  @b1 = @c1.parent
  @a1 = @b1.parent
  @d2 = Label.find_or_create_by_path %w(a1 b1 c2 d2)
  @c2 = @d2.parent
  @d3 = Label.find_or_create_by_path %w(a2 b2 c3 d3)
  @c3 = @d3.parent
  @b2 = @c3.parent
  @a2 = @b2.parent
  Label.update_all("sort_order = id")
end

def create_preorder_tree(suffix = "")
  %w(
    a/l/n/r
    a/l/n/q
    a/l/n/p
    a/l/n/o
    a/l/m
    a/b/h/i/j/k
    a/b/c/d/g
    a/b/c/d/f
    a/b/c/d/e
  ).shuffle.each { |ea| Label.find_or_create_by_path(ea.split('/').collect { |ea| "#{ea}#{suffix}" }) }

  Label.roots.each_with_index do |root, root_idx|
    root.order_value = root_idx
    root.save!
    root.self_and_descendants.each do |ea|
      ea.children.to_a.sort_by(&:name).each_with_index do |ea, idx|
        ea.order_value = idx
        ea.save!
      end
    end
  end
end

describe Label do

  context "destruction" do
    it "properly destroys descendents" do
      c = Label.find_or_create_by_path %w(a b c)
      b = c.parent
      a = c.root
      a.destroy
      Label.exists?(a).should be_false
      Label.exists?(b).should be_false
      Label.exists?(c).should be_false
    end
  end

  context "roots" do
    before :each do
      delete_all_labels
    end
    it "sorts alphabetically" do
      expected = (0..10).to_a
      expected.shuffle.each do |ea|
        Label.create! do |l|
          l.name = "root #{ea}"
          l.sort_order = ea
        end
      end
      Label.roots.collect { |ea| ea.sort_order }.should == expected
    end
  end

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
        delete_all_labels
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

    it "supports children << and add_child" do
      a = EventLabel.create!(:name => "a")
      b = DateLabel.new(:name => "b")
      a.children << b
      c = Label.new(:name => "c")
      b.add_child(c)

      a.self_and_descendants.collect do |ea|
        ea.class
      end.should == [EventLabel, DateLabel, Label]

      a.self_and_descendants.collect do |ea|
        ea.name
      end.should == %w(a b c)
    end
  end

  context "find_all_by_generation" do
    before :all do
      delete_all_labels
      create_label_tree
    end

    it "finds roots from the class method" do
      Label.find_all_by_generation(0).to_a.should == [@a1, @a2]
    end

    it "finds roots from themselves" do
      @a1.find_all_by_generation(0).to_a.should == [@a1]
    end

    it "finds itself for non-roots" do
      @b1.find_all_by_generation(0).to_a.should == [@b1]
    end

    it "finds children for roots" do
      Label.find_all_by_generation(1).to_a.should == [@b1, @b2]
    end

    it "finds children" do
      @a1.find_all_by_generation(1).to_a.should == [@b1]
      @b1.find_all_by_generation(1).to_a.should == [@c1, @c2]
    end

    it "finds grandchildren for roots" do
      Label.find_all_by_generation(2).to_a.should == [@c1, @c2, @c3]
    end

    it "finds grandchildren" do
      @a1.find_all_by_generation(2).to_a.should == [@c1, @c2]
      @b1.find_all_by_generation(2).to_a.should == [@d1, @d2]
    end

    it "finds great-grandchildren for roots" do
      Label.find_all_by_generation(3).to_a.should == [@d1, @d2, @d3]
    end
  end

  context "loading through self_and_ scopes" do
    before :all do
      delete_all_labels
      create_label_tree
    end

    it "self_and_descendants should result in one select" do
      DB_QUERIES.clear
      a1_array = @a1.self_and_descendants
      a1_array.collect { |ea| ea.name }.should == %w(a1 b1 c1 c2 d1 d2)
      DB_QUERIES.size.should == 1
    end

    it "self_and_ancestors should result in one select" do
      DB_QUERIES.clear
      d1_array = @d1.self_and_ancestors
      d1_array.collect { |ea| ea.name }.should == %w(d1 c1 b1 a1)
      DB_QUERIES.size.should == 1
    end
  end

  context "deterministically orders with polymorphic siblings" do
    before :each do
      @parent = Label.create!(:name => "parent")
      @a = EventLabel.new(:name => "a")
      @b = DirectoryLabel.new(:name => "b")
      @c = DateLabel.new(:name => "c")
      @parent.children << @a
      @a.append_sibling(@b)
      @b.append_sibling(@c)
    end

    it "when inserted before" do
      @b.append_sibling(@a)
      # Have to reload because the sort_order will have changed out from under the references:
      @b.reload.sort_order.should be < @a.reload.sort_order
      @a.reload.sort_order.should be < @c.reload.sort_order
    end

    it "when inserted before" do
      @b.append_sibling(@a)
      # Have to reload because the sort_order will have changed out from under the references:
      @b.reload.sort_order.should be < @a.reload.sort_order
      @a.reload.sort_order.should be < @c.reload.sort_order
    end
  end

  it "behaves like the readme" do
    root = Label.create(:name => "root")
    a = Label.create(:name => "a", :parent => root)
    b = Label.create(:name => "b")
    c = Label.create(:name => "c")

    a.append_sibling(b)
    root.reload.children.collect(&:name).should == %w(a b)
    root.reload.children.collect(&:sort_order).should == [0, 1]

    a.prepend_sibling(b)
    root.reload.children.collect(&:name).should == %w(b a)
    root.reload.children.collect(&:sort_order).should == [0, 1]

    a.append_sibling(c)
    root.reload.children.collect(&:name).should == %w(b a c)
    root.reload.children.collect(&:sort_order).should == [0, 1, 2]

    b.append_sibling(c)
    root.reload.children.collect(&:name).should == %w(b c a)
    root.reload.children.collect(&:sort_order).should == [0, 1, 2]
  end

  context "Deterministic siblings sort with custom integer column" do
    delete_all_labels
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
      labels(:c16).prepend_sibling(labels(:c17))
      labels(:c16).self_and_siblings.to_a.should == [labels(:c17), labels(:c16), labels(:c18), labels(:c19)]
      labels(:c19).reload.prepend_sibling(labels(:c16).reload)
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
      labels(:b2).prepend_sibling(labels(:c2))
      labels(:c2).ancestry_path.should == %w{a1 c2}
      labels(:c2).self_and_siblings.to_a.should == [labels(:b1), labels(:c2), labels(:b2)]
    end

    it "should move a node before another node which has an uninitialized sort_order" do
      labels(:f3).ancestry_path.should == %w{f3}
      labels(:e2).children << labels(:f3)
      labels(:f3).reload.ancestry_path.should == %w{a1 b2 c2 d2 e2 f3}
      labels(:f3).self_and_siblings.to_a.should == [labels(:f3)]
      labels(:f3).prepend_sibling labels(:f4)
      labels(:f3).siblings_before.to_a.should == [labels(:f4)]
      labels(:f3).self_and_siblings.to_a.should == [labels(:f4), labels(:f3)]
    end

    it "should move a node after another node which has an uninitialized sort_order" do
      labels(:f3).ancestry_path.should == %w{f3}
      labels(:e2).children << labels(:f3)
      labels(:f3).reload.ancestry_path.should == %w{a1 b2 c2 d2 e2 f3}
      labels(:f3).self_and_siblings.to_a.should == [labels(:f3)]
      labels(:f3).append_sibling labels(:f4)
      labels(:f3).siblings_after.to_a.should == [labels(:f4)]
      labels(:f3).self_and_siblings.to_a.should == [labels(:f3), labels(:f4)]
    end

    it "should move a node after another node" do
      labels(:c2).ancestry_path.should == %w{a1 b2 c2}
      labels(:b2).append_sibling(labels(:c2))
      labels(:c2).ancestry_path.should == %w{a1 c2}
      labels(:c2).self_and_siblings.to_a.should == [labels(:b1), labels(:b2), labels(:c2)]
      labels(:c2).append_sibling(labels(:e2))
      labels(:e2).self_and_siblings.to_a.should == [labels(:b1), labels(:b2), labels(:c2), labels(:e2)]
      labels(:a1).self_and_descendants.collect(&:name).should == %w(a1 b1 b2 c2 e2 d2 c1-six c1-seven c1-eight c1-nine)
      labels(:a1).leaves.collect(&:name).should == %w(b2 e2 d2 c1-six c1-seven c1-eight c1-nine)
    end
  end

  context "preorder" do
    it "returns descendants in proper order" do
      delete_all_labels
      create_preorder_tree
      a = Label.root
      a.name.should == "a"
      expected = ('a'..'r').to_a
      a.self_and_descendants_preordered.collect { |ea| ea.name }.should == expected
      Label.roots_and_descendants_preordered.collect { |ea| ea.name }.should == expected
      # Let's create the second root by hand so we can explicitly set the sort order
      Label.create! do |l|
        l.name = "a1"
        l.sort_order = a.sort_order + 1
      end
      create_preorder_tree("1")
      # Should be no change:
      a.reload.self_and_descendants_preordered.collect { |ea| ea.name }.should == expected
      expected += ('a'..'r').collect { |ea| "#{ea}1" }
      Label.roots_and_descendants_preordered.collect { |ea| ea.name }.should == expected
    end
  end unless ENV["DB"] == "sqlite"
end

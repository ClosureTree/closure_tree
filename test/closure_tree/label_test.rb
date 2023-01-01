# frozen_string_literal: true

require "test_helper"

module CorrectOrderValue
  def self.shared_examples(&block)
    describe "correct order_value" do
      before do
        instance_exec(&block)
        @root = @model.create(name: "root")
        @a, @b, @c = %w[a b c].map { |n| @root.children.create(name: n) }
      end

      it "should set order_value on roots" do
        assert_equal @expected_root_order_value, @root.order_value
      end

      it "should set order_value with siblings" do
        assert_equal 0, @a.order_value
        assert_equal 1, @b.order_value
        assert_equal 2, @c.order_value
      end

      it "should reset order_value when a node is moved to another location" do
        root2 = @model.create(name: "root2")
        root2.add_child @b
        assert_equal 0, @a.order_value
        assert_equal 0, @b.order_value
        assert_equal 1, @c.reload.order_value
      end
    end
  end
end

def create_label_tree
  @d1 = Label.find_or_create_by_path %w[a1 b1 c1 d1]
  @c1 = @d1.parent
  @b1 = @c1.parent
  @a1 = @b1.parent
  @d2 = Label.find_or_create_by_path %w[a1 b1 c2 d2]
  @c2 = @d2.parent
  @d3 = Label.find_or_create_by_path %w[a2 b2 c3 d3]
  @c3 = @d3.parent
  @b2 = @c3.parent
  @a2 = @b2.parent
  Label.update_all("#{Label._ct.order_column} = id")
end

def create_preorder_tree(suffix = "")
  %w[
    a/l/n/r
    a/l/n/q
    a/l/n/p
    a/l/n/o
    a/l/m
    a/b/h/i/j/k
    a/b/c/d/g
    a/b/c/d/f
    a/b/c/d/e
  ].shuffle.each { |ea| Label.find_or_create_by_path(ea.split("/").collect { |ea| "#{ea}#{suffix}" }) }

  Label.roots.each_with_index do |root, root_idx|
    root.order_value = root_idx
    yield(root) if block_given?
    root.save!
    root.self_and_descendants.each do |ea|
      ea.children.to_a.sort_by(&:name).each_with_index do |ea, idx|
        ea.order_value = idx
        yield(ea) if block_given?
        ea.save!
      end
    end
  end
end

describe Label do
  describe "destruction" do
    it "properly destroys descendents created with find_or_create_by_path" do
      c = Label.find_or_create_by_path %w[a b c]
      b = c.parent
      a = c.root
      a.destroy
      refute Label.exists?(id: [a.id, b.id, c.id])
    end

    it "properly destroys descendents created with add_child" do
      a = Label.create(name: "a")
      b = a.add_child Label.new(name: "b")
      c = b.add_child Label.new(name: "c")
      a.destroy
      refute Label.exists?(a.id)
      refute Label.exists?(b.id)
      refute Label.exists?(c.id)
    end

    it "properly destroys descendents created with <<" do
      a = Label.create(name: "a")
      b = Label.new(name: "b")
      a.children << b
      c = Label.new(name: "c")
      b.children << c
      a.destroy
      refute Label.exists?(a.id)
      refute Label.exists?(b.id)
      refute Label.exists?(c.id)
    end
  end

  describe "roots" do
    it "sorts alphabetically" do
      expected = (0..10).to_a
      expected.shuffle.each do |ea|
        Label.create! do |l|
          l.name = "root #{ea}"
          l.order_value = ea
        end
      end
      assert_equal expected, Label.roots.collect { |ea| ea.order_value }
    end
  end

  describe "Base Label class" do
    it "should find or create by path" do
      # class method:
      c = Label.find_or_create_by_path(%w[grandparent parent child])
      assert_equal %w[grandparent parent child], c.ancestry_path
      assert_equal "child", c.name
      assert_equal "parent", c.parent.name
    end
  end

  describe "Parent/child inverse relationships" do
    it "should associate both sides of the parent and child relationships" do
      parent = Label.new(name: "parent")
      child = parent.children.build(name: "child")
      assert parent.root?
      refute parent.leaf?
      refute child.root?
      assert child.leaf?
    end
  end

  describe "DateLabel" do
    it "should find or create by path" do
      date = DateLabel.find_or_create_by_path(%w[2011 November 23])
      assert_equal %w[2011 November 23], date.ancestry_path
      date.self_and_ancestors.each { |ea| assert_equal DateLabel, ea.class }
      assert_equal "23", date.name
      assert_equal "November", date.parent.name
    end
  end

  describe "DirectoryLabel" do
    it "should find or create by path" do
      dir = DirectoryLabel.find_or_create_by_path(%w[grandparent parent child])
      assert_equal %w[grandparent parent child], dir.ancestry_path
      assert_equal "child", dir.name
      assert_equal "parent", dir.parent.name
      assert_equal "grandparent", dir.parent.parent.name
      assert_equal "grandparent", dir.root.name
      refute_equal Label.find_or_create_by_path(%w[grandparent parent child]), dir.id
      dir.self_and_ancestors.each { |ea| assert_equal DirectoryLabel, ea.class }
    end
  end

  describe "Mixed class tree" do
    describe "preorder tree" do
      before do
        classes = [Label, DateLabel, DirectoryLabel, EventLabel]
        create_preorder_tree do |ea|
          ea.type = classes[ea.order_value % 4].to_s
        end
      end

      it "finds roots with specific classes" do
        assert_equal Label.where(name: "a").to_a, Label.roots
        assert DirectoryLabel.roots.empty?
        assert EventLabel.roots.empty?
      end

      it "all is limited to subclasses" do
        assert_equal %w[f h l n p].sort, DateLabel.all.map(&:name).sort
        assert_equal %w[g q].sort, DirectoryLabel.all.map(&:name).sort
        assert_equal %w[r], EventLabel.all.map(&:name)
      end

      it "returns descendents regardless of subclass" do
        assert_equal %w[Label DateLabel DirectoryLabel EventLabel].sort, Label.root.descendants.map { |ea|
                                                                           ea.class.to_s
                                                                         }.uniq.sort
      end
    end

    it "supports children << and add_child" do
      a = EventLabel.create!(name: "a")
      b = DateLabel.new(name: "b")
      a.children << b
      c = Label.new(name: "c")
      b.add_child(c)

      assert_equal [EventLabel, DateLabel, Label], a.self_and_descendants.collect { |ea| ea.class }
      assert_equal %w[a b c], a.self_and_descendants.collect { |ea| ea.name }
    end
  end

  describe "find_all_by_generation" do
    before do
      create_label_tree
    end

    it "finds roots from the class method" do
      assert_equal [@a1, @a2], Label.find_all_by_generation(0).to_a
    end

    it "finds roots from themselves" do
      assert_equal [@a1], @a1.find_all_by_generation(0).to_a
    end

    it "finds itself for non-roots" do
      assert_equal [@b1], @b1.find_all_by_generation(0).to_a
    end

    it "finds children for roots" do
      assert_equal [@b1, @b2], Label.find_all_by_generation(1).to_a
    end

    it "finds children" do
      assert_equal [@b1], @a1.find_all_by_generation(1).to_a
      assert_equal [@c1, @c2], @b1.find_all_by_generation(1).to_a
    end

    it "finds grandchildren for roots" do
      assert_equal [@c1, @c2, @c3], Label.find_all_by_generation(2).to_a
    end

    it "finds grandchildren" do
      assert_equal [@c1, @c2], @a1.find_all_by_generation(2).to_a
      assert_equal [@d1, @d2], @b1.find_all_by_generation(2).to_a
    end

    it "finds great-grandchildren for roots" do
      assert_equal [@d1, @d2, @d3], Label.find_all_by_generation(3).to_a
    end
  end

  describe "loading through self_and_ scopes" do
    before do
      create_label_tree
    end

    it "self_and_descendants should result in one select" do
      assert_database_queries_count(1) do
        a1_array = @a1.self_and_descendants
        assert_equal(%w[a1 b1 c1 c2 d1 d2], a1_array.collect { |ea| ea.name })
      end
    end

    it "self_and_ancestors should result in one select" do
      assert_database_queries_count(1) do
        d1_array = @d1.self_and_ancestors
        assert_equal(%w[d1 c1 b1 a1], d1_array.collect { |ea| ea.name })
      end
    end
  end

  describe "deterministically orders with polymorphic siblings" do
    before do
      @parent = Label.create!(name: "parent")
      @a, @b, @c, @d, @e, @f = ("a".."f").map { |ea| EventLabel.new(name: ea) }
      @parent.children << @a
      @a.append_sibling(@b)
      @b.append_sibling(@c)
      @c.append_sibling(@d)
      @parent.append_sibling(@e)
      @e.append_sibling(@f)
    end

    def name_and_order(enum)
      enum.map { |ea| [ea.name, ea.order_value] }
    end

    def children_name_and_order
      name_and_order(@parent.children.reload)
    end

    def roots_name_and_order
      name_and_order(Label.roots)
    end

    it "order_values properly" do
      assert_equal [["a", 0], ["b", 1], ["c", 2], ["d", 3]], children_name_and_order
    end

    it "when inserted before" do
      @b.append_sibling(@a)
      assert_equal [["b", 0], ["a", 1], ["c", 2], ["d", 3]], children_name_and_order
    end

    it "when inserted after" do
      @a.append_sibling(@c)
      assert_equal [["a", 0], ["c", 1], ["b", 2], ["d", 3]], children_name_and_order
    end

    it "when inserted before the first" do
      @a.prepend_sibling(@d)
      assert_equal [["d", 0], ["a", 1], ["b", 2], ["c", 3]], children_name_and_order
    end

    it "when inserted after the last" do
      @d.append_sibling(@b)
      assert_equal [["a", 0], ["c", 1], ["d", 2], ["b", 3]], children_name_and_order
    end

    it "prepends to root nodes" do
      @parent.prepend_sibling(@f)
      assert_equal [["f", 0], ["parent", 1], ["e", 2]], roots_name_and_order
    end
  end

  describe "doesn't order roots when requested" do
    before do
      @root1 = LabelWithoutRootOrdering.create!(name: "root1")
      @root2 = LabelWithoutRootOrdering.create!(name: "root2")
      @a, @b, @c, @d, @e = ("a".."e").map { |ea| LabelWithoutRootOrdering.new(name: ea) }
      @root1.children << @a
      @root1.append_child(@c)
      @root1.prepend_child(@d)

      # Reload is needed here and below because order values may have been adjusted in the DB during
      # prepend_child, append_sibling, etc.
      [@a, @c, @d].each(&:reload)

      @a.append_sibling(@b)
      [@a, @c, @d, @b].each(&:reload)
      @d.prepend_sibling(@e)
    end

    it "order_values properly" do
      assert @root1.reload.order_value.nil?
      orders_and_names = @root1.children.reload.map { |ea| [ea.name, ea.order_value] }
      assert_equal [["e", 0], ["d", 1], ["a", 2], ["b", 3], ["c", 4]], orders_and_names
    end

    it "raises on prepending and appending to root" do
      assert_raises ClosureTree::RootOrderingDisabledError do
        @root1.prepend_sibling(@f)
      end

      assert_raises ClosureTree::RootOrderingDisabledError do
        @root1.append_sibling(@f)
      end
    end

    it "returns empty array for siblings_before and after" do
      assert_equal [], @root1.siblings_before
      assert_equal [], @root1.siblings_after
    end

    unless sqlite?
      it "returns expected result for self_and_descendants_preordered" do
        assert_equal [@root1, @e, @d, @a, @b, @c], @root1.self_and_descendants_preordered.to_a
      end
    end

    it "raises on roots_and_descendants_preordered" do
      assert_raises ClosureTree::RootOrderingDisabledError do
        LabelWithoutRootOrdering.roots_and_descendants_preordered
      end
    end
  end

  describe "code in the readme" do
    it "creates STI label hierarchies" do
      child = Label.find_or_create_by_path([
        {type: "DateLabel", name: "2014"},
        {type: "DateLabel", name: "August"},
        {type: "DateLabel", name: "5"},
        {type: "EventLabel", name: "Visit the Getty Center"}
      ])
      assert child.is_a?(EventLabel)
      assert_equal "Visit the Getty Center", child.name
      assert_equal %w[5 August 2014], child.ancestors.map(&:name)
      assert_equal [DateLabel, DateLabel, DateLabel], child.ancestors.map(&:class)
    end

    it "appends and prepends siblings" do
      root = Label.create(name: "root")
      a = root.append_child(Label.new(name: "a"))
      b = Label.create(name: "b")
      c = Label.create(name: "c")

      a.append_sibling(b)
      assert_equal %w[a b], a.self_and_siblings.collect(&:name)
      assert_equal %w[a b], root.reload.children.collect(&:name)
      assert_equal [0, 1], root.children.collect(&:order_value)

      a.prepend_sibling(b)
      assert_equal %w[b a], a.self_and_siblings.collect(&:name)
      assert_equal %w[b a], root.reload.children.collect(&:name)
      assert_equal [0, 1], root.children.collect(&:order_value)

      a.append_sibling(c)
      assert_equal %w[b a c], a.self_and_siblings.collect(&:name)
      assert_equal %w[b a c], root.reload.children.collect(&:name)
      assert_equal [0, 1, 2], root.children.collect(&:order_value)

      # We need to reload b because it was updated by a.append_sibling(c)
      b.reload.append_sibling(c)
      assert_equal %w[b c a], root.reload.children.collect(&:name)
      assert_equal [0, 1, 2], root.children.collect(&:order_value)

      d = a.reload.append_sibling(Label.new(name: "d"))
      assert_equal %w[b c a d], d.self_and_siblings.collect(&:name)
      assert_equal [0, 1, 2, 3], d.self_and_siblings.collect(&:order_value)
    end
  end

  # https://github.com/mceachen/closure_tree/issues/84
  it "properly appends children with <<" do
    root = Label.create(name: "root")
    a = Label.create(name: "a", parent: root)
    b = Label.create(name: "b", parent: root)

    # Add a child to root at end of children.
    root.children << b
    assert_equal root, b.parent
    assert_equal %w[a b], a.self_and_siblings.collect(&:name)
    assert_equal %w[a b], root.reload.children.collect(&:name)
    assert_equal [0, 1], root.children.collect(&:order_value)
  end

  describe "#add_sibling" do
    it "should move a node before another node which has an uninitialized order_value" do
      f = Label.find_or_create_by_path %w[a b c d e fa]
      f0 = f.prepend_sibling(Label.new(name: "fb")) # < not alpha sort, so name shouldn't matter
      assert_equal %w[a b c d e fb], f0.ancestry_path
      assert_equal [f0], f.siblings_before.to_a
      assert f0.siblings_before.empty?
      assert_equal [f], f0.siblings_after
      assert f.siblings_after.empty?
      assert_equal [f0, f], f0.self_and_siblings
      assert_equal [f0, f], f.self_and_siblings
    end

    before do
      @f1 = Label.find_or_create_by_path %w[a1 b1 c1 d1 e1 f1]
    end

    it "should move a node to another tree" do
      f2 = Label.find_or_create_by_path %w[a2 b2 c2 d2 e2 f2]
      @f1.add_sibling(f2)
      assert_equal %w[a1 b1 c1 d1 e1 f2], f2.ancestry_path
      assert_equal [@f1, f2], @f1.parent.reload.children
    end

    it "should reorder old-parent siblings when a node moves to another tree" do
      f2 = Label.find_or_create_by_path %w[a2 b2 c2 d2 e2 f2]
      f3 = f2.prepend_sibling(Label.new(name: "f3"))
      f4 = f2.append_sibling(Label.new(name: "f4"))
      @f1.add_sibling(f2)
      assert_equal [0, 1], @f1.self_and_siblings.collect(&:order_value)
      assert_equal [0, 1], f3.self_and_siblings.collect(&:order_value)
      assert_equal %w[f1 f2], @f1.self_and_siblings.collect(&:name)
      assert_equal %w[f3 f4], f3.self_and_siblings.collect(&:name)
    end
  end

  describe "order_value must be set" do
    describe "with normal model" do
      CorrectOrderValue.shared_examples do
        @model = Label
        @expected_root_order_value = 0
      end
    end

    describe "without root ordering" do
      CorrectOrderValue.shared_examples do
        @model = LabelWithoutRootOrdering
        @expected_root_order_value = nil
      end
    end
  end

  describe "destructive reordering" do
    before do
      # to make sure order_value isn't affected by additional nodes:
      create_preorder_tree
      @root = Label.create(name: "root")
      @a = @root.children.create!(name: "a")
      @b = @a.append_sibling(Label.new(name: "b"))
      @c = @b.append_sibling(Label.new(name: "c"))
    end

    describe "doesn't create sort order gaps" do
      it "from head" do
        @a.destroy
        assert_equal [@b, @c], @root.reload.children
        assert_equal([0, 1], @root.children.map { |ea| ea.order_value })
      end

      it "from mid" do
        @b.destroy
        assert_equal [@a, @c], @root.reload.children
        assert_equal([0, 1], @root.children.map { |ea| ea.order_value })
      end

      it "from tail" do
        @c.destroy
        assert_equal [@a, @b], @root.reload.children
        assert_equal([0, 1], @root.children.map { |ea| ea.order_value })
      end
    end

    describe "add_sibling moves descendant nodes" do
      before do
        @roots = (0..10).map { |ea| Label.create(name: ea) }
        @first_root = @roots.first
        @last_root = @roots.last
      end

      it "should retain sort orders of descendants when moving to a new parent" do
        expected_order = ("a".."z").to_a.shuffle
        expected_order.map { |ea| @first_root.add_child(Label.new(name: ea)) }
        actual_order = @first_root.children.reload.pluck(:name)
        assert_equal expected_order, actual_order
        @last_root.append_child(@first_root)
        assert_equal(%w[10 0] + expected_order, @last_root.self_and_descendants.pluck(:name))
      end

      it "should retain sort orders of descendants when moving within the same new parent" do
        path = ("a".."z").to_a
        z = @first_root.find_or_create_by_path(path)
        z_children_names = (100..150).to_a.shuffle.map { |ea| ea.to_s }
        z_children_names.reverse_each { |ea| z.prepend_child(Label.new(name: ea)) }
        assert_equal z_children_names, z.children.reload.pluck(:name)
        a = @first_root.find_by_path(["a"])
        # move b up to a's level:
        b = a.children.first
        a.add_sibling(b)
        assert_equal @first_root, b.parent
        assert_equal z_children_names, z.children.reload.pluck(:name)
      end
    end

    it "shouldn't fail if all children are destroyed" do
      roots = Label.roots.to_a
      roots.each { |ea| ea.children.destroy_all }
      assert_equal roots.sort, Label.all.to_a.sort
    end
  end

  describe "descendent destruction" do
    it "properly destroys descendents created with add_child" do
      a = Label.create(name: "a")
      b = Label.new(name: "b")
      a.add_child b
      c = Label.new(name: "c")
      b.add_child c
      a.destroy
      refute Label.exists?(id: [a.id, b.id, c.id])
    end

    it "properly destroys descendents created with <<" do
      a = Label.create(name: "a")
      b = Label.new(name: "b")
      a.children << b
      c = Label.new(name: "c")
      b.children << c
      a.destroy
      refute Label.exists?(id: [a.id, b.id, c.id])
    end
  end

  unless sqlite?
    describe "preorder" do
      it "returns descendants in proper order" do
        create_preorder_tree
        a = Label.root
        assert_equal "a", a.name
        expected = ("a".."r").to_a
        assert_equal expected, a.self_and_descendants_preordered.collect { |ea| ea.name }
        assert_equal expected, Label.roots_and_descendants_preordered.collect { |ea| ea.name }
        # Let's create the second root by hand so we can explicitly set the sort order
        Label.create! do |l|
          l.name = "a1"
          l.order_value = a.order_value + 1
        end
        create_preorder_tree("1")
        # Should be no change:
        assert_equal expected, a.reload.self_and_descendants_preordered.collect { |ea| ea.name }
        expected += ("a".."r").collect { |ea| "#{ea}1" }
        assert_equal expected, Label.roots_and_descendants_preordered.collect { |ea| ea.name }
      end
    end
  end

  describe "hash_tree" do
    before do
      @a = EventLabel.create(name: "a")
      @b = DateLabel.create(name: "b")
      @c = DirectoryLabel.create(name: "c")
      (1..3).each { |i| DirectoryLabel.create!(name: "c#{i}", mother_id: @c.id) }
    end

    it "should return tree with correct scope when called on class" do
      tree = DirectoryLabel.hash_tree
      assert_equal 1, tree.keys.size
      assert_equal @c, tree.keys.first
      assert_equal 3, tree[@c].keys.size
    end

    it "should return tree with correct scope when called on all" do
      tree = DirectoryLabel.all.hash_tree
      assert_equal 1, tree.keys.size
      assert_equal @c, tree.keys.first
      assert_equal 3, tree[@c].keys.size
    end

    it "should return tree with correct scope when called on scope chain" do
      tree = Label.where(name: "b").hash_tree
      assert_equal 1, tree.keys.size
      assert_equal @b, tree.keys.first
      assert_equal({}, tree[@b])
    end
  end

  describe "relationship between nodes" do
    before do
      create_label_tree
    end

    it "checks parent of node" do
      assert @a1.parent_of?(@b1)
      assert @c2.parent_of?(@d2)
      refute @c1.parent_of?(@b1)
    end

    it "checks children of node" do
      assert @d1.child_of?(@c1)
      assert @c2.child_of?(@b1)
      refute @c3.child_of?(@b1)
    end

    it "checks root of node" do
      assert @a1.root_of?(@d1)
      assert @a1.root_of?(@c2)
      refute @a2.root_of?(@c2)
    end

    it "checks ancestor of node" do
      assert @a1.ancestor_of?(@d1)
      assert @b1.ancestor_of?(@d1)
      refute @b1.ancestor_of?(@c3)
    end

    it "checks descendant of node" do
      assert @c1.descendant_of?(@a1)
      assert @d2.descendant_of?(@a1)
      refute @b1.descendant_of?(@a2)
    end

    it "checks descendant of node" do
      assert @b1.family_of?(@b1)
      assert @a1.family_of?(@c1)
      assert @d3.family_of?(@a2)
      assert @c1.family_of?(@d2)
      refute @c3.family_of?(@a1)
    end
  end
end

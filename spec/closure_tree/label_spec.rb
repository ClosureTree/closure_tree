require 'spec_helper'

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
  Label.update_all("#{Label._ct.order_column} = id")
end

def create_preorder_tree(suffix = "", &block)
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

RSpec.describe Label do
  context "destruction" do
    it "properly destroys descendents created with find_or_create_by_path" do
      c = Label.find_or_create_by_path %w(a b c)
      b = c.parent
      a = c.root
      a.destroy
      expect(Label.exists?(id: [a.id, b.id, c.id])).to be_falsey
    end

    it "properly destroys descendents created with add_child" do
      a = Label.create(name: 'a')
      b = a.add_child Label.new(name: 'b')
      c = b.add_child Label.new(name: 'c')
      a.destroy
      expect(Label.exists?(a.id)).to be_falsey
      expect(Label.exists?(b.id)).to be_falsey
      expect(Label.exists?(c.id)).to be_falsey
    end

    it "properly destroys descendents created with <<" do
      a = Label.create(name: 'a')
      b = Label.new(name: 'b')
      a.children << b
      c = Label.new(name: 'c')
      b.children << c
      a.destroy
      expect(Label.exists?(a.id)).to be_falsey
      expect(Label.exists?(b.id)).to be_falsey
      expect(Label.exists?(c.id)).to be_falsey
    end
  end

  context "roots" do
    it "sorts alphabetically" do
      expected = (0..10).to_a
      expected.shuffle.each do |ea|
        Label.create! do |l|
          l.name = "root #{ea}"
          l.order_value = ea
        end
      end
      expect(Label.roots.collect { |ea| ea.order_value }).to eq(expected)
    end
  end

  context "Base Label class" do
    it "should find or create by path" do
      # class method:
      c = Label.find_or_create_by_path(%w{grandparent parent child})
      expect(c.ancestry_path).to eq(%w{grandparent parent child})
      expect(c.name).to eq("child")
      expect(c.parent.name).to eq("parent")
    end
  end

  context "Parent/child inverse relationships" do
    it "should associate both sides of the parent and child relationships" do
      parent = Label.new(:name => 'parent')
      child = parent.children.build(:name => 'child')
      expect(parent).to be_root
      expect(parent).not_to be_leaf
      expect(child).not_to be_root
      expect(child).to be_leaf
    end
  end

  context "DateLabel" do
    it "should find or create by path" do
      date = DateLabel.find_or_create_by_path(%w{2011 November 23})
      expect(date.ancestry_path).to eq(%w{2011 November 23})
      date.self_and_ancestors.each { |ea| expect(ea.class).to eq(DateLabel) }
      expect(date.name).to eq("23")
      expect(date.parent.name).to eq("November")
    end
  end

  context "DirectoryLabel" do
    it "should find or create by path" do
      dir = DirectoryLabel.find_or_create_by_path(%w{grandparent parent child})
      expect(dir.ancestry_path).to eq(%w{grandparent parent child})
      expect(dir.name).to eq("child")
      expect(dir.parent.name).to eq("parent")
      expect(dir.parent.parent.name).to eq("grandparent")
      expect(dir.root.name).to eq("grandparent")
      expect(dir.id).not_to eq(Label.find_or_create_by_path(%w{grandparent parent child}))
      dir.self_and_ancestors.each { |ea| expect(ea.class).to eq(DirectoryLabel) }
    end
  end

  context "Mixed class tree" do
    context "preorder tree" do
      before do
        classes = [Label, DateLabel, DirectoryLabel, EventLabel]
        create_preorder_tree do |ea|
          ea.type = classes[ea.order_value % 4].to_s
        end
      end
      it "finds roots with specific classes" do
        expect(Label.roots).to eq(Label.where(:name => 'a').to_a)
        expect(DirectoryLabel.roots).to be_empty
        expect(EventLabel.roots).to be_empty
      end

      it "all is limited to subclasses" do
        expect(DateLabel.all.map(&:name)).to match_array(%w(f h l n p))
        expect(DirectoryLabel.all.map(&:name)).to match_array(%w(g q))
        expect(EventLabel.all.map(&:name)).to eq(%w(r))
      end

      it "returns descendents regardless of subclass" do
        expect(Label.root.descendants.map { |ea| ea.class.to_s }.uniq).to match_array(
          %w(Label DateLabel DirectoryLabel EventLabel)
        )
      end
    end

    it "supports children << and add_child" do
      a = EventLabel.create!(:name => "a")
      b = DateLabel.new(:name => "b")
      a.children << b
      c = Label.new(:name => "c")
      b.add_child(c)

      expect(a.self_and_descendants.collect do |ea|
        ea.class
      end).to eq([EventLabel, DateLabel, Label])

      expect(a.self_and_descendants.collect do |ea|
        ea.name
      end).to eq(%w(a b c))
    end
  end

  context "find_all_by_generation" do
    before :each do
      create_label_tree
    end

    it "finds roots from the class method" do
      expect(Label.find_all_by_generation(0).to_a).to eq([@a1, @a2])
    end

    it "finds roots from themselves" do
      expect(@a1.find_all_by_generation(0).to_a).to eq([@a1])
    end

    it "finds itself for non-roots" do
      expect(@b1.find_all_by_generation(0).to_a).to eq([@b1])
    end

    it "finds children for roots" do
      expect(Label.find_all_by_generation(1).to_a).to eq([@b1, @b2])
    end

    it "finds children" do
      expect(@a1.find_all_by_generation(1).to_a).to eq([@b1])
      expect(@b1.find_all_by_generation(1).to_a).to eq([@c1, @c2])
    end

    it "finds grandchildren for roots" do
      expect(Label.find_all_by_generation(2).to_a).to eq([@c1, @c2, @c3])
    end

    it "finds grandchildren" do
      expect(@a1.find_all_by_generation(2).to_a).to eq([@c1, @c2])
      expect(@b1.find_all_by_generation(2).to_a).to eq([@d1, @d2])
    end

    it "finds great-grandchildren for roots" do
      expect(Label.find_all_by_generation(3).to_a).to eq([@d1, @d2, @d3])
    end
  end

  context "loading through self_and_ scopes" do
    before :each do
      create_label_tree
    end

    it "self_and_descendants should result in one select" do
      expect(count_queries do
        a1_array = @a1.self_and_descendants
        expect(a1_array.collect { |ea| ea.name }).to eq(%w(a1 b1 c1 c2 d1 d2))
      end).to eq(1)
    end

    it "self_and_ancestors should result in one select" do
      expect(count_queries do
        d1_array = @d1.self_and_ancestors
        expect(d1_array.collect { |ea| ea.name }).to eq(%w(d1 c1 b1 a1))
      end).to eq(1)
    end
  end

  context "deterministically orders with polymorphic siblings" do
    before :each do
      @parent = Label.create!(:name => 'parent')
      @a, @b, @c, @d, @e, @f = ('a'..'f').map { |ea| EventLabel.new(:name => ea) }
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

    it 'order_values properly' do
      expect(children_name_and_order).to eq([['a', 0], ['b', 1], ['c', 2], ['d', 3]])
    end

    it 'when inserted before' do
      @b.append_sibling(@a)
      expect(children_name_and_order).to eq([['b', 0], ['a', 1], ['c', 2], ['d', 3]])
    end

    it 'when inserted after' do
      @a.append_sibling(@c)
      expect(children_name_and_order).to eq([['a', 0], ['c', 1], ['b', 2], ['d', 3]])
    end

    it 'when inserted before the first' do
      @a.prepend_sibling(@d)
      expect(children_name_and_order).to eq([['d', 0], ['a', 1], ['b', 2], ['c', 3]])
    end

    it 'when inserted after the last' do
      @d.append_sibling(@b)
      expect(children_name_and_order).to eq([['a', 0], ['c', 1], ['d', 2], ['b', 3]])
    end

    it 'prepends to root nodes' do
      @parent.prepend_sibling(@f)
      expect(roots_name_and_order).to eq([['f', 0], ['parent', 1], ['e', 2]])
    end
  end

  context "doesn't order roots when requested" do
    before :each do
      @root1 = LabelWithoutRootOrdering.create!(:name => 'root1')
      @root2 = LabelWithoutRootOrdering.create!(:name => 'root2')
      @a, @b, @c, @d, @e = ('a'..'e').map { |ea| LabelWithoutRootOrdering.new(:name => ea) }
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

    it 'order_values properly' do
      expect(@root1.reload.order_value).to be_nil
      orders_and_names = @root1.children.reload.map { |ea| [ea.name, ea.order_value] }
      expect(orders_and_names).to eq([['e', 0], ['d', 1], ['a', 2], ['b', 3], ['c', 4]])
    end

    it 'raises on prepending and appending to root' do
      expect { @root1.prepend_sibling(@f) }.to raise_error(ClosureTree::RootOrderingDisabledError)
      expect { @root1.append_sibling(@f) }.to raise_error(ClosureTree::RootOrderingDisabledError)
    end

    it 'returns empty array for siblings_before and after' do
      expect(@root1.siblings_before).to eq([])
      expect(@root1.siblings_after).to eq([])
    end

    it 'returns expected result for self_and_descendants_preordered' do
      expect(@root1.self_and_descendants_preordered.to_a).to eq([@root1, @e, @d, @a, @b, @c])
    end unless sqlite? # sqlite doesn't have a power function.

    it 'raises on roots_and_descendants_preordered' do
      expect { LabelWithoutRootOrdering.roots_and_descendants_preordered }.to raise_error(
        ClosureTree::RootOrderingDisabledError)
    end
  end

  describe 'code in the readme' do
    it 'creates STI label hierarchies' do
      child = Label.find_or_create_by_path([
        {type: 'DateLabel', name: '2014'},
        {type: 'DateLabel', name: 'August'},
        {type: 'DateLabel', name: '5'},
        {type: 'EventLabel', name: 'Visit the Getty Center'}
      ])
      expect(child).to be_a(EventLabel)
      expect(child.name).to eq('Visit the Getty Center')
      expect(child.ancestors.map(&:name)).to eq(%w(5 August 2014))
      expect(child.ancestors.map(&:class)).to eq([DateLabel, DateLabel, DateLabel])
    end

    it 'appends and prepends siblings' do
      root = Label.create(name: 'root')
      a = root.append_child(Label.new(name: 'a'))
      b = Label.create(name: 'b')
      c = Label.create(name: 'c')

      a.append_sibling(b)
      expect(a.self_and_siblings.collect(&:name)).to eq(%w(a b))
      expect(root.reload.children.collect(&:name)).to eq(%w(a b))
      expect(root.children.collect(&:order_value)).to eq([0, 1])

      a.prepend_sibling(b)
      expect(a.self_and_siblings.collect(&:name)).to eq(%w(b a))
      expect(root.reload.children.collect(&:name)).to eq(%w(b a))
      expect(root.children.collect(&:order_value)).to eq([0, 1])

      a.append_sibling(c)
      expect(a.self_and_siblings.collect(&:name)).to eq(%w(b a c))
      expect(root.reload.children.collect(&:name)).to eq(%w(b a c))
      expect(root.children.collect(&:order_value)).to eq([0, 1, 2])

      # We need to reload b because it was updated by a.append_sibling(c)
      b.reload.append_sibling(c)
      expect(root.reload.children.collect(&:name)).to eq(%w(b c a))
      expect(root.children.collect(&:order_value)).to eq([0, 1, 2])

      # We need to reload a because it was updated by b.append_sibling(c)
      d = a.reload.append_sibling(Label.new(:name => "d"))
      expect(d.self_and_siblings.collect(&:name)).to eq(%w(b c a d))
      expect(d.self_and_siblings.collect(&:order_value)).to eq([0, 1, 2, 3])
    end
  end

  # https://github.com/mceachen/closure_tree/issues/84
  it "properly appends children with <<" do
    root = Label.create(:name => "root")
    a = Label.create(:name => "a", :parent => root)
    b = Label.create(:name => "b", :parent => root)

    # Add a child to root at end of children.
    root.children << b
    expect(b.parent).to eq(root)
    expect(a.self_and_siblings.collect(&:name)).to eq(%w(a b))
    expect(root.reload.children.collect(&:name)).to eq(%w(a b))
    expect(root.children.collect(&:order_value)).to eq([0, 1])
  end

  context "#add_sibling" do
    it "should move a node before another node which has an uninitialized order_value" do
      f = Label.find_or_create_by_path %w(a b c d e fa)
      f0 = f.prepend_sibling(Label.new(:name => "fb")) # < not alpha sort, so name shouldn't matter
      expect(f0.ancestry_path).to eq(%w(a b c d e fb))
      expect(f.siblings_before.to_a).to eq([f0])
      expect(f0.siblings_before).to be_empty
      expect(f0.siblings_after).to eq([f])
      expect(f.siblings_after).to be_empty
      expect(f0.self_and_siblings).to eq([f0, f])
      expect(f.self_and_siblings).to eq([f0, f])
    end

    let(:f1) { Label.find_or_create_by_path %w(a1 b1 c1 d1 e1 f1) }

    it "should move a node to another tree" do
      f2 = Label.find_or_create_by_path %w(a2 b2 c2 d2 e2 f2)
      f1.add_sibling(f2)
      expect(f2.ancestry_path).to eq(%w(a1 b1 c1 d1 e1 f2))
      expect(f1.parent.reload.children).to eq([f1, f2])
    end

    it "should reorder old-parent siblings when a node moves to another tree" do
      f2 = Label.find_or_create_by_path %w(a2 b2 c2 d2 e2 f2)
      f3 = f2.prepend_sibling(Label.new(:name => "f3"))
      f4 = f2.append_sibling(Label.new(:name => "f4"))
      f1.add_sibling(f2)
      expect(f1.self_and_siblings.collect(&:order_value)).to eq([0, 1])
      expect(f3.self_and_siblings.collect(&:order_value)).to eq([0, 1])
      expect(f1.self_and_siblings.collect(&:name)).to eq(%w(f1 f2))
      expect(f3.self_and_siblings.collect(&:name)).to eq(%w(f3 f4))
    end
  end

  context "order_value must be set" do
    shared_examples_for "correct order_value" do
      before do
        @root = model.create(name: 'root')
        @a, @b, @c = %w(a b c).map { |n| @root.children.create(name: n) }
      end

      it 'should set order_value on roots' do
        expect(@root.order_value).to eq(expected_root_order_value)
      end

      it 'should set order_value with siblings' do
        expect(@a.order_value).to eq(0)
        expect(@b.order_value).to eq(1)
        expect(@c.order_value).to eq(2)
      end

      it 'should reset order_value when a node is moved to another location' do
        root2 = model.create(name: 'root2')
        root2.add_child @b
        expect(@a.order_value).to eq(0)
        expect(@b.order_value).to eq(0)
        expect(@c.reload.order_value).to eq(1)
      end
    end

    context "with normal model" do
      let(:model) { Label }
      let(:expected_root_order_value) { 0 }
      it_behaves_like "correct order_value"
    end

    context "without root ordering" do
      let(:model) { LabelWithoutRootOrdering }
      let(:expected_root_order_value) { nil }
      it_behaves_like "correct order_value"
    end
  end

  context "destructive reordering" do
    before :each do
      # to make sure order_value isn't affected by additional nodes:
      create_preorder_tree
      @root = Label.create(:name => 'root')
      @a = @root.children.create!(:name => 'a')
      @b = @a.append_sibling(Label.new(:name => 'b'))
      @c = @b.append_sibling(Label.new(:name => 'c'))
    end
    context "doesn't create sort order gaps" do
      it 'from head' do
        @a.destroy
        expect(@root.reload.children).to eq([@b, @c])
        expect(@root.children.map { |ea| ea.order_value }).to eq([0, 1])
      end
      it 'from mid' do
        @b.destroy
        expect(@root.reload.children).to eq([@a, @c])
        expect(@root.children.map { |ea| ea.order_value }).to eq([0, 1])
      end
      it 'from tail' do
        @c.destroy
        expect(@root.reload.children).to eq([@a, @b])
        expect(@root.children.map { |ea| ea.order_value }).to eq([0, 1])
      end
    end

    context 'add_sibling moves descendant nodes' do
      let(:roots) { (0..10).map { |ea| Label.create(name: ea) } }
      let(:first_root) { roots.first }
      let(:last_root) { roots.last }
      it 'should retain sort orders of descendants when moving to a new parent' do
        expected_order = ('a'..'z').to_a.shuffle
        expected_order.map { |ea| first_root.add_child(Label.new(name: ea)) }
        actual_order = first_root.children.reload.pluck(:name)
        expect(actual_order).to eq(expected_order)
        last_root.append_child(first_root)
        expect(last_root.self_and_descendants.pluck(:name)).to eq(%w(10 0) + expected_order)
      end

      it 'should retain sort orders of descendants when moving within the same new parent' do
        path = ('a'..'z').to_a
        z = first_root.find_or_create_by_path(path)
        z_children_names = (100..150).to_a.shuffle.map { |ea| ea.to_s }
        z_children_names.reverse.each { |ea| z.prepend_child(Label.new(name: ea)) }
        expect(z.children.reload.pluck(:name)).to eq(z_children_names)
        a = first_root.find_by_path(['a'])
        # move b up to a's level:
        b = a.children.first
        a.add_sibling(b)
        expect(b.parent).to eq(first_root)
        expect(z.children.reload.pluck(:name)).to eq(z_children_names)
      end
    end

    it "shouldn't fail if all children are destroyed" do
      roots = Label.roots.to_a
      roots.each { |ea| ea.children.destroy_all }
      expect(Label.all.to_a).to match_array(roots)
    end
  end

  context 'descendent destruction' do
    it 'properly destroys descendents created with add_child' do
      a = Label.create(name: 'a')
      b = Label.new(name: 'b')
      a.add_child b
      c = Label.new(name: 'c')
      b.add_child c
      a.destroy
      expect(Label.exists?(id: [a.id, b.id, c.id])).to be_falsey
    end

    it 'properly destroys descendents created with <<' do
      a = Label.create(name: 'a')
      b = Label.new(name: 'b')
      a.children << b
      c = Label.new(name: 'c')
      b.children << c
      a.destroy
      expect(Label.exists?(id: [a.id, b.id, c.id])).to be_falsey
    end
  end

  context 'preorder' do
    it 'returns descendants in proper order' do
      create_preorder_tree
      a = Label.root
      expect(a.name).to eq('a')
      expected = ('a'..'r').to_a
      expect(a.self_and_descendants_preordered.collect { |ea| ea.name }).to eq(expected)
      expect(Label.roots_and_descendants_preordered.collect { |ea| ea.name }).to eq(expected)
      # Let's create the second root by hand so we can explicitly set the sort order
      Label.create! do |l|
        l.name = "a1"
        l.order_value = a.order_value + 1
      end
      create_preorder_tree('1')
      # Should be no change:
      expect(a.reload.self_and_descendants_preordered.collect { |ea| ea.name }).to eq(expected)
      expected += ('a'..'r').collect { |ea| "#{ea}1" }
      expect(Label.roots_and_descendants_preordered.collect { |ea| ea.name }).to eq(expected)
    end
  end unless sqlite? # sqlite doesn't have a power function.

  context 'hash_tree' do
    before do
      @a = EventLabel.create(name: 'a')
      @b = DateLabel.create(name: 'b')
      @c = DirectoryLabel.create(name: 'c')
      (1..3).each { |i| DirectoryLabel.create!(name: "c#{ i }", mother_id: @c.id) }
    end
    it 'should return tree with correct scope when called on class' do
      tree = DirectoryLabel.hash_tree
      expect(tree.keys.size).to eq(1)
      expect(tree.keys.first).to eq(@c)
      expect(tree[@c].keys.size).to eq(3)
    end
    it 'should return tree with correct scope when called on all' do
      tree = DirectoryLabel.all.hash_tree
      expect(tree.keys.size).to eq(1)
      expect(tree.keys.first).to eq(@c)
      expect(tree[@c].keys.size).to eq(3)
    end
    it 'should return tree with correct scope when called on scope chain' do
      tree = Label.where(name: 'b').hash_tree
      expect(tree.keys.size).to eq(1)
      expect(tree.keys.first).to eq(@b)
      expect(tree[@b]).to eq({})
    end
  end

  context 'relationship between nodes' do
    before do
      create_label_tree
    end

    it "checks parent of node" do
      expect(@a1.parent_of?(@b1)).to be_truthy
      expect(@c2.parent_of?(@d2)).to be_truthy
      expect(@c1.parent_of?(@b1)).to be_falsey
    end

    it "checks children of node" do
      expect(@d1.child_of?(@c1)).to be_truthy
      expect(@c2.child_of?(@b1)).to be_truthy
      expect(@c3.child_of?(@b1)).to be_falsey
    end

    it "checks root of node" do
      expect(@a1.root_of?(@d1)).to be_truthy
      expect(@a1.root_of?(@c2)).to be_truthy
      expect(@a2.root_of?(@c2)).to be_falsey
    end

    it "checks ancestor of node" do
      expect(@a1.ancestor_of?(@d1)).to be_truthy
      expect(@b1.ancestor_of?(@d1)).to be_truthy
      expect(@b1.ancestor_of?(@c3)).to be_falsey
    end

    it "checks descendant of node" do
      expect(@c1.descendant_of?(@a1)).to be_truthy
      expect(@d2.descendant_of?(@a1)).to be_truthy
      expect(@b1.descendant_of?(@a2)).to be_falsey
    end

    it "checks descendant of node" do
      expect(@b1.family_of?(@b1)).to be_truthy
      expect(@a1.family_of?(@c1)).to be_truthy
      expect(@d3.family_of?(@a2)).to be_truthy
      expect(@c1.family_of?(@d2)).to be_truthy
      expect(@c3.family_of?(@a1)).to be_falsey
    end
  end

end

shared_examples_for 'Tag (with fixtures)' do

  let (:tag_class) { described_class }
  let (:tag_hierarchy_class) { described_class.hierarchy_class }

  describe 'Tag (with fixtures)' do
    fixtures :tags
    before do
      tag_class.rebuild!
      DestroyedTag.delete_all
    end

    context 'adding children' do
      it 'should work explicitly' do
        sb = Tag.create!(:name => 'Santa Barbara')
        sb.leaf?.should_not be_nil
        tags(:california).add_child sb
        sb.leaf?.should_not be_nil
        validate_city_tag sb
      end

      it 'should work implicitly through the collection' do
        eg = Tag.create!(:name => 'El Granada')
        eg.leaf?.should_not be_nil
        tags(:california).children << eg
        eg.leaf?.should_not be_nil
        validate_city_tag eg
      end

      it 'should fail to create ancestor loops' do
        child = tags(:child)
        parent = child.parent
        child.add_child(parent) # this should fail
        parent.valid?.should be_false
        child.reload.children.should be_empty
        parent.reload.children.should == [child]
      end

      it 'should move non-leaves' do
        # This is what the fixture should encode:
        tags(:d2).ancestry_path.should == %w{a1 b2 c2 d2}
        tags(:b1).add_child(tags(:c2))
        tags(:b2).leaf?.should_not be_nil
        tags(:b1).children.include?(tags(:c2)).should be_true
        tags(:d2).reload.ancestry_path.should == %w{a1 b1 c2 d2}
      end

      it 'should move leaves' do
        l = Tag.find_or_create_by_path(%w{leaftest branch1 leaf})
        b2 = Tag.find_or_create_by_path(%w{leaftest branch2})
        b2.children << l
        l.ancestry_path.should == %w{leaftest branch2 leaf}
      end

      it 'should move roots' do
        l1 = Tag.find_or_create_by_path(%w{roottest1 branch1 leaf1})
        l2 = Tag.find_or_create_by_path(%w{roottest2 branch2 leaf2})
        l1.children << l2.root
        l1.reload.ancestry_path.should == %w{roottest1 branch1 leaf1}
        l2.reload.ancestry_path.should == %w{roottest1 branch1 leaf1 roottest2 branch2 leaf2}
      end

      it 'should cascade delete all children' do
        b2 = tags(:b2)
        entities = b2.self_and_descendants.to_a
        names = b2.self_and_descendants.collect { |t| t.name }
        b2.destroy
        entities.each { |e| Tag.find_by_id(e.id).should be_nil }
        DestroyedTag.all.collect { |t| t.name }.should =~ names
      end
    end

    context 'injected attributes' do
      it 'should compute level correctly' do
        tags(:grandparent).level.should == 0
        tags(:parent).level.should == 1
        tags(:child).level.should == 2
      end

      it 'should determine parent correctly' do
        tags(:grandparent).parent.should == nil
        tags(:parent).parent.should == tags(:grandparent)
        tags(:child).parent.should == tags(:parent)
      end

      it 'should have a sane children collection' do
        tags(:grandparent).children.include? tags(:parent).should be_true
        tags(:parent).children.include? tags(:child).should be_true
        tags(:child).children.should be_empty
      end

      it 'assembles siblings correctly' do
        tags(:b1).siblings.to_a.should =~ [tags(:b2)]
        tags(:a1).siblings.to_a.should =~ (Tag.roots.to_a - [tags(:a1)])
        tags(:a1).self_and_siblings.to_a.should =~ Tag.roots.to_a

        # must be ordered
        tags(:indoor).siblings.to_a.should == [tags(:home), tags(:museum), tags(:outdoor), tags(:united_states)]
        tags(:indoor).self_and_siblings.to_a.should == [tags(:home), tags(:indoor), tags(:museum), tags(:outdoor), tags(:united_states)]
      end

      it 'assembles siblings before correctly' do
        tags(:home).siblings_before.to_a.should == []
        tags(:indoor).siblings_before.to_a.should == [tags(:home)]
        tags(:outdoor).siblings_before.to_a.should == [tags(:home), tags(:indoor), tags(:museum)]
        tags(:united_states).siblings_before.to_a.should == [tags(:home), tags(:indoor), tags(:museum), tags(:outdoor)]
      end

      it 'assembles siblings after correctly' do
        tags(:indoor).siblings_after.to_a.should == [tags(:museum), tags(:outdoor), tags(:united_states)]
        tags(:outdoor).siblings_after.to_a.should == [tags(:united_states)]
        tags(:united_states).siblings_after.to_a.should == []
      end

      it 'assembles ancestors' do
        tags(:child).ancestors.should == [tags(:parent), tags(:grandparent)]
        tags(:child).self_and_ancestors.should == [tags(:child), tags(:parent), tags(:grandparent)]
      end

      it 'assembles descendants' do
        tags(:parent).descendants.should == [tags(:child)]
        tags(:parent).self_and_descendants.should == [tags(:parent), tags(:child)]
        tags(:grandparent).descendants.should == [tags(:parent), tags(:child)]
        tags(:grandparent).self_and_descendants.should == [tags(:grandparent), tags(:parent), tags(:child)]
        tags(:grandparent).self_and_descendants.collect { |t| t.name }.join(" > ").should == 'grandparent > parent > child'
      end
    end

    def validate_city_tag city
      tags(:california).children.include?(city).should_not be_nil
      city.ancestors.should == [tags(:california), tags(:united_states), tags(:places)]
      city.self_and_ancestors.should == [city, tags(:california), tags(:united_states), tags(:places)]
    end

  end
end

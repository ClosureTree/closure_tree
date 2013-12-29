shared_examples_for 'Tag (with fixtures)' do

  let (:tag_class) { described_class }
  let (:tag_hierarchy_class) { described_class.hierarchy_class }

  describe 'Tag (with fixtures)' do
    fixtures :tags
    before :each do
      setup_fixtures
      tag_class.rebuild!
      DestroyedTag.delete_all
    end

    context 'adding children' do

    context 'injected attributes' do

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

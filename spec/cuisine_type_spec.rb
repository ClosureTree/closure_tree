require 'spec_helper'

def assert_lineage(e, m)
  m.parent.should == e
  m.self_and_ancestors.should == [m, e]

  # make sure reloading doesn't affect the self_and_ancestors:
  m.reload
  m.self_and_ancestors.should == [m, e]
end

describe CuisineType do
  it "finds self and parents when children << is used" do
    e = CuisineType.new(:name => "e")
    m = CuisineType.new(:name => "m")
    e.children << m
    e.save
    assert_lineage(e, m)
  end

  it "finds self and parents properly if the constructor is used" do
    e = CuisineType.create(:name => "e")
    m = CuisineType.create(:name => "m", :parent => e)
    assert_lineage(e, m)
  end

  it "sets the table_name of the hierarchy class properly" do
    CuisineTypeHierarchy.table_name.should == ActiveRecord::Base.table_name_prefix + "cuisine_type_hierarchies" + ActiveRecord::Base.table_name_suffix
  end

  it 'fixes self_and_ancestors properly on reparenting' do
    a = CuisineType.create! :name => 'a'
    b = CuisineType.create! :name => 'b'
    b.self_and_ancestors.to_a.should == [b]
    a.children << b
    b.self_and_ancestors.to_a.should == [b, a]
  end
end

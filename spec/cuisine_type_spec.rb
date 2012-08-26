require 'spec_helper'

describe CuisineType do
  it "finds self and parents properly" do
    e = CuisineType.new(:name => "e")
    m = CuisineType.new(:name => "m")
    e.children << m
    e.save

    m.parent.should == e
    m.self_and_ancestors.should == [m, e]

    # make sure reloading doesn't affect the self_and_ancestors:
    m.reload
    m.self_and_ancestors.should == [m, e]
  end

  it "sets the table_name of the hierarchy class properly" do
    CuisineTypeHierarchy.table_name.should == "cuisine_type_hierarchies"
  end
end

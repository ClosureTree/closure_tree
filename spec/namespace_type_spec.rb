require 'spec_helper'

describe Namespace::Type do

  context "class injection" do
    it "should build hierarchy classname correctly" do
      Namespace::Type.hierarchy_class.to_s.should == "Namespace::TypeHierarchy"
      Namespace::Type._ct.hierarchy_class_name.should == "Namespace::TypeHierarchy"
      Namespace::Type._ct.short_hierarchy_class_name.should == "TypeHierarchy"
    end
  end

end

require 'spec_helper'

describe Namespace::Type do

  context "class injection" do
    it "should build hierarchy classname correctly" do
      Namespace::Type.hierarchy_class.to_s.should == "Namespace::TypeHierarchy"
      Namespace::Type.hierarchy_class_name.should == "Namespace::TypeHierarchy"
    end

    it "should build hierarchy tablename correctly" do
      Namespace::Type.hierarchy_table_name.should == "namespace_type_hierarchies"
    end
  end

end

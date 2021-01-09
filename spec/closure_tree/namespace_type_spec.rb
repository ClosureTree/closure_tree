require 'spec_helper'

RSpec.describe Namespace::Type do
  context "class injection" do
    it "should build hierarchy classname correctly" do
      expect(Namespace::Type.hierarchy_class.to_s).to eq("Namespace::TypeHierarchy")
      expect(Namespace::Type._ct.hierarchy_class_name).to eq("Namespace::TypeHierarchy")
      expect(Namespace::Type._ct.short_hierarchy_class_name).to eq("TypeHierarchy")
    end
  end
end

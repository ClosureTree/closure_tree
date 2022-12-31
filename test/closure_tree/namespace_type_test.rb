# frozen_string_literal: true

require 'test_helper'

describe Namespace::Type do
  describe 'class injection' do
    it 'should build hierarchy classname correctly' do
      assert_equal 'Namespace::TypeHierarchy', Namespace::Type.hierarchy_class.to_s
      assert_equal 'Namespace::TypeHierarchy', Namespace::Type._ct.hierarchy_class_name
      assert_equal 'TypeHierarchy', Namespace::Type._ct.short_hierarchy_class_name
    end
  end
end

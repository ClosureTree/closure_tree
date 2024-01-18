# frozen_string_literal: true

require 'test_helper'

describe 'Configuration' do
  it 'returns connection to the pool after has_closure_tree setup' do
    class TypeDuplicate < ActiveRecord::Base
      self.table_name = "namespace_type#{table_name_suffix}"
      has_closure_tree
    end

    assert_nil TypeDuplicate.connection_pool.active_connection?
  end

  it 'returns connection to the pool after has_closure_tree setup with order' do
    class MetalDuplicate < ActiveRecord::Base
      self.table_name = "#{table_name_prefix}metal#{table_name_suffix}"
      has_closure_tree order: 'sort_order', name_column: 'value'
    end

    refute MetalDuplicate.connection_pool.active_connection?
  end

  it 'returns connection to the pool after has_closure_tree_root setup' do
    class GroupDuplicate < ActiveRecord::Base
      self.table_name = "#{table_name_prefix}group#{table_name_suffix}"
      has_closure_tree_root :root_user
    end

    refute GroupDuplicate.connection_pool.active_connection?
  end
end

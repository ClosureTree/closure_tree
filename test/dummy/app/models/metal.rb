# frozen_string_literal: true

class Metal < ApplicationRecord
  self.table_name = "#{table_name_prefix}metal#{table_name_suffix}"
  has_closure_tree order: 'sort_order', name_column: 'value'
  self.inheritance_column = 'metal_type'
end

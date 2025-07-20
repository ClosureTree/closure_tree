# frozen_string_literal: true

class LabelWithoutRootOrdering < ActiveRecord::Base
  self.table_name = 'labels'
  has_closure_tree parent_column_name: 'mother_id',
                   name_column: 'name',
                   order: 'column_whereby_ordering_is_inferred',
                   numeric_order: true,
                   dont_order_roots: true
end

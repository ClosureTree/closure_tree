# frozen_string_literal: true

class MultiScopedItem < ApplicationRecord
  self.table_name = 'scoped_items'
  has_closure_tree order: :sort_order, numeric_order: true, scope: [:user_id, :group_id]
end


# frozen_string_literal: true

class ScopedItem < ApplicationRecord
  has_closure_tree order: :sort_order, numeric_order: true, scope: :user_id
end


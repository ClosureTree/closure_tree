# frozen_string_literal: true

class Label < ApplicationRecord
  # make sure order doesn't matter
  acts_as_tree order: :column_whereby_ordering_is_inferred, # <- symbol, and not "sort_order"
               numeric_order: true,
               parent_column_name: 'mother_id',
               dependent: :destroy

  def to_s
    "#{self.class}: #{name}"
  end
end

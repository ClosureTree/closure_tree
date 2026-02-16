# frozen_string_literal: true

class MemoryTag < LiteRecord
  has_closure_tree order: :sort_order, numeric_order: true
end

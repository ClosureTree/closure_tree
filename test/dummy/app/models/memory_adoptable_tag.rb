# frozen_string_literal: true

class MemoryAdoptableTag < LiteRecord
  has_closure_tree dependent: :adopt, name_column: 'name'
end

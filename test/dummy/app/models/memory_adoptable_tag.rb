# frozen_string_literal: true

class MemoryAdoptableTag < SqliteRecord
  has_closure_tree dependent: :adopt, name_column: 'name'
end


# frozen_string_literal: true

class SecondaryAdoptableTag < SecondaryRecord
  has_closure_tree dependent: :adopt, name_column: 'name'
end

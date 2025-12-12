# frozen_string_literal: true

class AdoptableTag < ApplicationRecord
  has_closure_tree dependent: :adopt, name_column: 'name'
end

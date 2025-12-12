# frozen_string_literal: true

class MysqlAdoptableTag < MysqlRecord
  has_closure_tree dependent: :adopt, name_column: 'name'
end

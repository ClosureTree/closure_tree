# frozen_string_literal: true

class MysqlRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection :secondary
end

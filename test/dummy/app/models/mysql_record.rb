# frozen_string_literal: true

class MysqlRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :secondary, reading: :secondary }
end

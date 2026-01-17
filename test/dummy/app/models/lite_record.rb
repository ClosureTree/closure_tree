# frozen_string_literal: true

class LiteRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :lite, reading: :lite }
end

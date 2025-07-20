# frozen_string_literal: true

class SqliteRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :sqlite, reading: :sqlite }
end

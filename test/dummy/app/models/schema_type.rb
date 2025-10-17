# frozen_string_literal: true

class SchemaType < ApplicationRecord
  self.table_name = 'test_schema.schema_types'
  has_closure_tree order: :name

  def to_s
    name
  end
end

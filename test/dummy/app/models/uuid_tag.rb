# frozen_string_literal: true

class UuidTag < ApplicationRecord
  self.primary_key = :uuid
  before_create :set_uuid
  has_closure_tree dependent: :destroy, order: 'name', parent_column_name: 'parent_uuid'
  before_destroy :add_destroyed_tag

  def set_uuid
    self.uuid = SecureRandom.uuid
  end

  def to_s
    name
  end

  def add_destroyed_tag
    # Proof for the tests that the destroy rather than the delete method was called:
    DestroyedTag.create(name: to_s)
  end
end

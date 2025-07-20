# frozen_string_literal: true

class Tag < ApplicationRecord
  has_closure_tree dependent: :destroy, order: :name
  before_destroy :add_destroyed_tag

  def to_s
    name
  end

  def add_destroyed_tag
    # Proof for the tests that the destroy rather than the delete method was called:
    DestroyedTag.create(name: to_s)
  end
end

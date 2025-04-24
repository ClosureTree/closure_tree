# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # connects_to database: { writing: :primary, reading: :primary }
end

class SecondDatabaseRecord < ActiveRecord::Base
  self.abstract_class = true

  # connects_to database: { writing: :secondary, reading: :secondary }
end
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

class UUIDTag < ApplicationRecord
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

class DestroyedTag < ApplicationRecord
end

class Group < ApplicationRecord
  has_closure_tree_root :root_user
end

class Grouping < ApplicationRecord
  has_closure_tree_root :root_person, class_name: 'User', foreign_key: :group_id
end

class UserSet < ApplicationRecord
  has_closure_tree_root :root_user, class_name: 'Useur'
end

class Team < ApplicationRecord
  has_closure_tree_root :root_user, class_name: 'User', foreign_key: :grp_id
end

class User < ApplicationRecord
  acts_as_tree parent_column_name: 'referrer_id',
               name_column: 'email',
               hierarchy_class_name: 'ReferralHierarchy',
               hierarchy_table_name: 'referral_hierarchies'

  has_many :contracts, inverse_of: :user
  belongs_to :group # Can't use and don't need inverse_of here when using has_closure_tree_root.

  def indirect_contracts
    Contract.where(user_id: descendant_ids)
  end

  def to_s
    email
  end
end

class Contract < ApplicationRecord
  belongs_to :user, inverse_of: :contracts
  belongs_to :contract_type, inverse_of: :contracts
end

class ContractType < ApplicationRecord
  has_many :contracts, inverse_of: :contract_type
end

class Block < ApplicationRecord
  acts_as_tree order: :column_whereby_ordering_is_inferred, # <- symbol, and not "sort_order"
               numeric_order: true,
               dependent: :destroy,
               order_belong_to: :user_id
end

class Label < ApplicationRecord
  # make sure order doesn't matter
  acts_as_tree order: :column_whereby_ordering_is_inferred, # <- symbol, and not "sort_order"
               numeric_order: true,
               parent_column_name: 'mother_id',
               dependent: :destroy

  def to_s
    "#{self.class}: #{name}"
  end
end

class EventLabel < Label
end

class DateLabel < Label
end

class DirectoryLabel < Label
end

class LabelWithoutRootOrdering < ApplicationRecord
  # make sure order doesn't matter
  acts_as_tree order: :column_whereby_ordering_is_inferred, # <- symbol, and not "sort_order"
               numeric_order: true,
               dont_order_roots: true,
               parent_column_name: 'mother_id',
               hierarchy_table_name: 'label_hierarchies'

  self.table_name = "#{table_name_prefix}labels#{table_name_suffix}"

  def to_s
    "#{self.class}: #{name}"
  end
end

class CuisineType < ApplicationRecord
  acts_as_tree
end

module Namespace
  def self.table_name_prefix
    'namespace_'
  end

  class Type < ApplicationRecord
    has_closure_tree dependent: :destroy
  end
end

class Metal < ApplicationRecord
  self.table_name = "#{table_name_prefix}metal#{table_name_suffix}"
  has_closure_tree order: 'sort_order', name_column: 'value'
  self.inheritance_column = 'metal_type'
end

class Adamantium < Metal
end

class Unobtanium < Metal
end

class MenuItem < SecondDatabaseRecord
  has_closure_tree touch: true, with_advisory_lock: false
end

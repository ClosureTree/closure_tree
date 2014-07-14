require 'uuidtools'

class Tag < ActiveRecord::Base
  acts_as_tree :dependent => :destroy, :order => :name
  before_destroy :add_destroyed_tag
  attr_accessible :name, :title if _ct.use_attr_accessible?

  def to_s
    name
  end

  def add_destroyed_tag
    # Proof for the tests that the destroy rather than the delete method was called:
    DestroyedTag.create(:name => name)
  end
end

class UUIDTag < ActiveRecord::Base
  self.primary_key = :uuid
  before_create :set_uuid
  acts_as_tree :dependent => :destroy, :order => 'name', :parent_column_name => 'parent_uuid'
  before_destroy :add_destroyed_tag
  attr_accessible :name, :title if _ct.use_attr_accessible?

  def set_uuid
    self.uuid = UUIDTools::UUID.timestamp_create.to_s
  end

  def to_s
    name
  end

  def add_destroyed_tag
    # Proof for the tests that the destroy rather than the delete method was called:
    DestroyedTag.create(:name => name)
  end
end

class DestroyedTag < ActiveRecord::Base
  attr_accessible :name if Tag._ct.use_attr_accessible?
end

class User < ActiveRecord::Base
  acts_as_tree :parent_column_name => "referrer_id",
    :name_column => 'email',
    :hierarchy_class_name => 'ReferralHierarchy',
    :hierarchy_table_name => 'referral_hierarchies'

  has_many :contracts

  def indirect_contracts
    Contract.where(:user_id => descendant_ids)
  end

  attr_accessible :email, :referrer if _ct.use_attr_accessible?

  def to_s
    email
  end
end

class Contract < ActiveRecord::Base
  belongs_to :user
end

class Label < ActiveRecord::Base
  # make sure order doesn't matter
  acts_as_tree :order => :column_whereby_ordering_is_inferred, # <- symbol, and not "sort_order"
    :parent_column_name => "mother_id",
    :dependent => :destroy

  attr_accessible :name if _ct.use_attr_accessible?

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

class CuisineType < ActiveRecord::Base
  acts_as_tree
end

module Namespace
  class Type < ActiveRecord::Base
    acts_as_tree :dependent => :destroy
    attr_accessible :name if _ct.use_attr_accessible?
  end
end

class Metal < ActiveRecord::Base
  self.table_name = "#{table_name_prefix}metal#{table_name_suffix}"
  acts_as_tree :order => 'sort_order'
  self.inheritance_column = 'metal_type'
end

class MenuItem < ActiveRecord::Base
  acts_as_tree(touch: true, with_advisory_lock: false, cache_child_count: true)
end

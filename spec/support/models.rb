require 'uuidtools'

class Tag < ActiveRecord::Base
  acts_as_tree :dependent => :destroy, :order => "name"
  before_destroy :add_destroyed_tag

  unless defined?(ActiveModel::ForbiddenAttributesProtection)
    attr_accessible :name
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
  unless defined?(ActiveModel::ForbiddenAttributesProtection)
    attr_accessible :name
  end
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

  unless defined?(ActiveModel::ForbiddenAttributesProtection)
    attr_accessible :email, :referrer
  end

  def to_s
    email
  end
end

class Contract < ActiveRecord::Base
  belongs_to :user
end

class Label < ActiveRecord::Base
  attr_accessible :name # <- make sure order doesn't matter
  unless defined?(ActiveModel::ForbiddenAttributesProtection)
    attr_accessible :name # < - make sure order doesn't matter
  end
  acts_as_tree :order => :sort_order, # <- LOOK IT IS A SYMBOL OMG
    :parent_column_name => "mother_id",
    :dependent => :destroy

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
    attr_accessible :name
  end
end

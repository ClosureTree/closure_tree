class Tag < ActiveRecord::Base
  acts_as_tree
  validates_presence_of :name
end

class Tag < ActiveRecord::Base
  acts_as_tree
  belongs_to :tag, :foreign_key => parent_id
end

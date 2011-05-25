class TagsHierarchy < ActiveRecord::Base
  belongs_to :ancestor, :class_name => "Tag"
  belongs_to :descendant, :class_name => "Tag"
end

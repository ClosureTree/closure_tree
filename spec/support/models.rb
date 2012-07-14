class Tag < ActiveRecord::Base
  acts_as_tree :dependent => :destroy, :order => "name"
  before_destroy :add_destroyed_tag
  attr_accessible :name

  def to_s
    name
  end

  def add_destroyed_tag
    # Proof for the tests that the destroy rather than the delete method was called:
    DestroyedTag.create(:name => name)
  end
end

class DestroyedTag < ActiveRecord::Base
  attr_accessible :name
end

class User < ActiveRecord::Base
  acts_as_tree :parent_column_name => "referrer_id",
    :name_column => 'email',
    :hierarchy_table_name => 'referral_hierarchies'
  attr_accessible :email, :referrer

  def to_s
    email
  end
end

class Label < ActiveRecord::Base
  acts_as_tree :order => "sort_order"
  attr_accessible :name

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

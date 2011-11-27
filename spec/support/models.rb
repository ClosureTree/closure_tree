class Tag < ActiveRecord::Base
  acts_as_tree :dependent => :destroy
  before_destroy :add_destroyed_tag

  def to_s
    name
  end

  def add_destroyed_tag
    # Proof for the tests that the destroy rather than the delete method was called:
    DestroyedTag.create(:name => name)
  end
end

class DestroyedTag < ActiveRecord::Base
end

class User < ActiveRecord::Base
  acts_as_tree :parent_column_name => "referrer_id",
    :name_column => 'email',
    :hierarchy_table_name => 'referral_hierarchies'

  def to_s
    email
  end
end

class Label < ActiveRecord::Base
  acts_as_tree
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
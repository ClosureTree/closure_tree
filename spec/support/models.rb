class Tag < ActiveRecord::Base
  acts_as_tree
  def to_s
    name
  end
end

class User < ActiveRecord::Base
  acts_as_tree :parent_column_name => "referrer_id", :name_column => 'email'

  def to_s
    email
  end
end

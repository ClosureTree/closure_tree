class Tag < ActiveRecord::Base
  acts_as_tree
end

class User < ActiveRecord::Base
  acts_as_tree :parent_column_name => "referrer_id", :name_column => 'email'
end

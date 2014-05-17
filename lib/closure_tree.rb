require 'active_record'
require 'closure_tree/acts_as_tree'

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :extend, ClosureTree::ActsAsTree
end

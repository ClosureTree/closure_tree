require 'closure_tree/acts_as_tree'

ActiveRecord::Base.send :extend, ClosureTree::ActsAsTree

require 'closure_tree/support'
require 'closure_tree/model'
require 'closure_tree/deterministic_ordering'
require 'closure_tree/numeric_deterministic_ordering'
require 'closure_tree/with_advisory_lock'

module ClosureTree
  module ActsAsTree
    def acts_as_tree(options = {})
      class_attribute :_ct
      self._ct = ClosureTree::Support.new(self, options)

      # Auto-inject the hierarchy table
      # See https://github.com/patshaughnessy/class_factory/blob/master/lib/class_factory/class_factory.rb
      class_attribute :hierarchy_class
      self.hierarchy_class = _ct.hierarchy_class_for_model

      include ClosureTree::Model
      include ClosureTree::WithAdvisoryLock

      if _ct.order_option
        include ClosureTree::DeterministicOrdering
        include ClosureTree::DeterministicNumericOrdering if _ct.order_is_numeric?
      end
    end
  end
end

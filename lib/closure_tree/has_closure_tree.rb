# frozen_string_literal: true

module ClosureTree
  module HasClosureTree
    def has_closure_tree(options = {})
      options.assert_valid_keys(
        :parent_column_name,
        :dependent,
        :hierarchy_class_name,
        :hierarchy_table_name,
        :name_column,
        :order,
        :dont_order_roots,
        :numeric_order,
        :touch,
        :with_advisory_lock,
        :advisory_lock_name
      )

      class_attribute :_ct
      self._ct = ClosureTree::Support.new(self, options)

      # Auto-inject the hierarchy table
      # See https://github.com/patshaughnessy/class_factory/blob/master/lib/class_factory/class_factory.rb
      class_attribute :hierarchy_class
      self.hierarchy_class = _ct.hierarchy_class_for_model

      # Include modules - HierarchyMaintenance provides callbacks that Model associations depend on
      # The order is maintained for consistency, but associations are now set up after all includes
      include ClosureTree::HierarchyMaintenance
      include ClosureTree::Model
      include ClosureTree::Finders
      include ClosureTree::HashTree
      include ClosureTree::Digraphs

      include ClosureTree::DeterministicOrdering if _ct.order_option?
      include ClosureTree::NumericDeterministicOrdering if _ct.order_is_numeric?

      # Include AssociationSetup last to ensure all dependencies are ready
      include ClosureTree::AssociationSetup

      connection_pool.release_connection
    end

    # Only alias acts_as_tree if it's not already defined (to avoid conflicts with other gems)
    alias acts_as_tree has_closure_tree unless method_defined?(:acts_as_tree)
  end
end

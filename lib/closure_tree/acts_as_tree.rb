require 'with_advisory_lock'
require 'closure_tree/support'
require 'closure_tree/hierarchy_maintenance'
require 'closure_tree/model'
require 'closure_tree/finders'
require 'closure_tree/hash_tree'
require 'closure_tree/digraphs'
require 'closure_tree/deterministic_ordering'
require 'closure_tree/numeric_deterministic_ordering'

module ClosureTree
  module ActsAsTree
    def acts_as_tree(options = {})
      options.assert_valid_keys(:name, :dependent, :order,
                                :parent_column_name, :name_column,
                                :hierarchy_class_name, :hierarchy_table_name,
                                :with_advisory_lock, :base_class)

      class_attribute :_ct
      self._ct = ClosureTree::Support.new(self, options)

      # Auto-inject the hierarchy table
      # See https://github.com/patshaughnessy/class_factory/blob/master/lib/class_factory/class_factory.rb
      class_attribute :hierarchy_class
      self.hierarchy_class = _ct.hierarchy_class_for_model

      # tests fail if you include Model before HierarchyMaintenance wtf
      include ClosureTree::HierarchyMaintenance
      include ClosureTree::Model
      include ClosureTree::Finders
      include ClosureTree::HashTree
      include ClosureTree::Digraphs

      include ClosureTree::DeterministicOrdering if _ct.order_option?
      include ClosureTree::NumericDeterministicOrdering if _ct.order_is_numeric?
    rescue StandardError => e
      # Support Heroku's database-less assets:precompile pre-deploy step:
      raise e unless ENV['DATABASE_URL'].to_s.include?('//user:pass@127.0.0.1/') && ENV['RAILS_GROUPS'] == 'assets'
    end
  end
end

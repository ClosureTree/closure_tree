# frozen_string_literal: true

require 'active_support/concern'

module ClosureTree
  # This concern sets up the ActiveRecord associations after all other modules are included.
  # It must be included last to ensure that HierarchyMaintenance callbacks are already set up.
  module AssociationSetup
    extend ActiveSupport::Concern

    included do
      belongs_to :parent, nil,
                 class_name: _ct.model_class.to_s,
                 foreign_key: _ct.parent_column_name,
                 inverse_of: :children,
                 touch: _ct.options[:touch],
                 optional: true

      order_by_generations = -> { Arel.sql("#{_ct.quoted_hierarchy_table_name}.generations ASC") }

      has_many :children, *_ct.has_many_order_with_option, class_name: _ct.model_class.to_s,
                                                           foreign_key: _ct.parent_column_name,
                                                           dependent: _ct.options[:dependent],
                                                           inverse_of: :parent do
        # We have to redefine hash_tree because the activerecord relation is already scoped to parent_id.
        def hash_tree(options = {})
          # we want limit_depth + 1 because we don't do self_and_descendants.
          limit_depth = options[:limit_depth]
          _ct.hash_tree(@association.owner.descendants, limit_depth ? limit_depth + 1 : nil)
        end
      end

      has_many :ancestor_hierarchies, *_ct.has_many_order_without_option(order_by_generations),
               class_name: _ct.hierarchy_class_name,
               foreign_key: 'descendant_id'

      has_many :self_and_ancestors, *_ct.has_many_order_without_option(order_by_generations),
               through: :ancestor_hierarchies,
               source: :ancestor

      has_many :descendant_hierarchies, *_ct.has_many_order_without_option(order_by_generations),
               class_name: _ct.hierarchy_class_name,
               foreign_key: 'ancestor_id'

      has_many :self_and_descendants, *_ct.has_many_order_with_option(order_by_generations),
               through: :descendant_hierarchies,
               source: :descendant
    end
  end
end
require 'active_support/concern'

module ClosureTree
  module Model
    extend ActiveSupport::Concern

    included do
      belongs_to :parent,
                 class_name: _ct.model_class.to_s,
                 foreign_key: _ct.parent_column_name,
                 inverse_of: :children,
                 touch: _ct.options[:touch],
                 counter_cache: _ct.options[:cache_child_count] ? :child_count : false

      # TODO, remove when activerecord 3.2 support is dropped
      attr_accessible :parent if _ct.use_attr_accessible?

      order_by_generations = "#{_ct.quoted_hierarchy_table_name}.generations asc"

      has_many :children, *_ct.has_many_with_order_option(
        class_name: _ct.model_class.to_s,
        foreign_key: _ct.parent_column_name,
        dependent: _ct.options[:dependent],
        inverse_of: :parent)

      has_many :ancestor_hierarchies, *_ct.has_many_without_order_option(
        class_name: _ct.hierarchy_class_name,
        foreign_key: 'descendant_id',
        order: order_by_generations)

      has_many :self_and_ancestors, *_ct.has_many_without_order_option(
        through: :ancestor_hierarchies,
        source: :ancestor,
        order: order_by_generations)

      has_many :descendant_hierarchies, *_ct.has_many_without_order_option(
        class_name: _ct.hierarchy_class_name,
        foreign_key: 'ancestor_id',
        order: order_by_generations)

      has_many :self_and_descendants, *_ct.has_many_with_order_option(
        through: :descendant_hierarchies,
        source: :descendant,
        order: order_by_generations)
    end

    # Delegate to the Support instance on the class:
    def _ct
      self.class._ct
    end

    # Returns true if this node has no parents.
    def root?
      # Accessing the parent will fetch that row from the database,
      # so if we are persisted, just check that the parent_id column is nil.
      persisted? ? _ct_parent_id.nil? : parent.nil?
    end

    # Returns true if this node has a parent, and is not a root.
    def child?
      !root?
    end

    # Returns true if this node has no children.
    def leaf?
      children.empty?
    end

    # Returns the farthest ancestor, or self if +root?+
    def root
      self_and_ancestors.where(_ct.parent_column_name.to_sym => nil).first
    end

    def leaves
      self_and_descendants.leaves
    end

    def depth
      ancestors.size
    end

    alias_method :level, :depth

    def ancestors
      without_self(self_and_ancestors)
    end

    def ancestor_ids
      _ct.ids_from(ancestors)
    end

    def self_and_ancestors_ids
      _ct.ids_from(self_and_ancestors)
    end

    # Returns an array, root first, of self_and_ancestors' values of the +to_s_column+, which defaults
    # to the +name_column+.
    # (so child.ancestry_path == +%w{grandparent parent child}+
    def ancestry_path(to_s_column = _ct.name_column)
      self_and_ancestors.reverse.map { |n| n.send to_s_column.to_sym }
    end

    def child_ids
      _ct.ids_from(children)
    end

    def descendants
      without_self(self_and_descendants)
    end

    def self_and_descendant_ids
      _ct.ids_from(self_and_descendants)
    end

    def descendant_ids
      _ct.ids_from(descendants)
    end

    def self_and_siblings
      _ct.scope_with_order(_ct.base_class.where(_ct.parent_column_sym => _ct_parent_id))
    end

    def siblings
      without_self(self_and_siblings)
    end

    def sibling_ids
      _ct.ids_from(siblings)
    end

    # Alias for appending to the children collection.
    # You can also add directly to the children collection, if you'd prefer.
    def add_child(child_node)
      children << child_node
      child_node
    end

    def _ct_parent_id
      read_attribute(_ct.parent_column_sym)
    end

    def _ct_quoted_parent_id
      _ct.quoted_value(_ct_parent_id)
    end

    def _ct_id
      read_attribute(_ct.model_class.primary_key)
    end

    def _ct_quoted_id
      _ct.quoted_value(_ct_id)
    end
  end
end

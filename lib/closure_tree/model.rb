require 'active_support/concern'

module ClosureTree
  module Model
    extend ActiveSupport::Concern

    included do

      belongs_to :parent, nil, **_ct.belongs_to_with_optional_option(
        class_name: _ct.model_class.to_s,
        foreign_key: _ct.parent_column_name,
        inverse_of: :children,
        touch: _ct.options[:touch],
        optional: true)

      order_by_generations = -> { Arel.sql("#{_ct.quoted_hierarchy_table_name}.generations ASC") }

      has_many :children, *_ct.has_many_order_with_option, **{
        class_name: _ct.model_class.to_s,
        foreign_key: _ct.parent_column_name,
        dependent: _ct.options[:dependent],
        inverse_of: :parent } do
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

    # enumerable of ancestors, immediate parent is first, root is last.
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
      self_and_ancestors.map { |n| n.send to_s_column.to_sym }.reverse
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

    # node's parent is this record
    def parent_of?(node)
      self == node.parent
    end

    # node's root is this record
    def root_of?(node)
      self == node.root
    end

    # node's ancestors include this record
    def ancestor_of?(node)
      node.ancestors.include? self
    end

    # node is record's ancestor
    def descendant_of?(node)
      self.ancestors.include? node
    end

    # node is record's parent
    def child_of?(node)
      self.parent == node
    end

    # node and record have a same root
    def family_of?(node)
      self.root == node.root
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

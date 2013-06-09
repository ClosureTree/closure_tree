require 'active_support/concern'

module ClosureTree
  module Model
    extend ActiveSupport::Concern

    included do
      belongs_to :parent,
        :class_name => _ct.model_class.to_s,
        :foreign_key => _ct.parent_column_name

      attr_accessible :parent if _ct.use_attr_accessible?

      order_by_generations = "#{_ct.quoted_hierarchy_table_name}.generations asc"

      has_many :children, *_ct.has_many_with_order_option(
        :class_name => _ct.model_class.to_s,
        :foreign_key => _ct.parent_column_name,
        :dependent => _ct.options[:dependent])

      has_many :ancestor_hierarchies, *_ct.has_many_without_order_option(
        :class_name => _ct.hierarchy_class_name,
        :foreign_key => "descendant_id",
        :order => order_by_generations)

      has_many :self_and_ancestors, *_ct.has_many_without_order_option(
        :through => :ancestor_hierarchies,
        :source => :ancestor,
        :order => order_by_generations)

      has_many :descendant_hierarchies, *_ct.has_many_without_order_option(
        :class_name => _ct.hierarchy_class_name,
        :foreign_key => "ancestor_id",
        :order => order_by_generations)

      # TODO: FIXME: this collection currently ignores sort_order
      # (because the quoted_table_named would need to be joined in to get to the order column)

      has_many :self_and_descendants, *_ct.has_many_with_order_option(
        :through => :descendant_hierarchies,
        :source => :descendant,
        :order => order_by_generations)

      scope :without, lambda { |instance|
        if instance.new_record?
          all
        else
          where(["#{_ct.quoted_table_name}.#{_ct.base_class.primary_key} != ?", instance.id])
        end
      }
    end

    # Delegate to the Support instance on the class:
    def _ct
      self.class._ct
    end

    # Returns true if this node has no parents.
    def root?
      _ct_parent_id.nil?
    end

    # Returns true if this node has a parent, and is not a root.
    def child?
      !parent.nil?
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

    alias :level :depth

    def ancestors
      without_self(self_and_ancestors)
    end

    def ancestor_ids
      _ct.ids_from(ancestors)
    end

    # Returns an array, root first, of self_and_ancestors' values of the +to_s_column+, which defaults
    # to the +name_column+.
    # (so child.ancestry_path == +%w{grandparent parent child}+
    def ancestry_path(to_s_column = _ct.name_column)
      self_and_ancestors.reverse.collect { |n| n.send to_s_column.to_sym }
    end

    def child_ids
      _ct.ids_from(children)
    end

    def descendants
      without_self(self_and_descendants)
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

    # override this method in your model class if you want a different digraph label.
    def to_digraph_label
      _ct.has_name? ? read_attribute(_ct.name_column) : to_s
    end

    def _ct_parent_id
      read_attribute(_ct.parent_column_sym)
    end

    def _ct_id
      read_attribute(_ct.model_class.primary_key)
    end

    def without_self(scope)
      scope.without(self)
    end

    def to_dot_digraph
      self.class.to_dot_digraph(self_and_descendants)
    end

    module ClassMethods
      def roots
        _ct.scope_with_order(where(_ct.parent_column_name => nil))
      end

      def with_ancestor(*ancestors)
        ancestor_ids = ancestors.map { |ea| ea.is_a?(ActiveRecord::Base) ? ea._ct_id : ea }
        scope = ancestor_ids.blank? ? scoped : joins(:ancestor_hierarchies).
          where("#{_ct.hierarchy_table_name}.ancestor_id" => ancestor_ids).
          where("#{_ct.hierarchy_table_name}.generations > 0").
          readonly(false)
        _ct.scope_with_order(scope)
      end

      # Returns an arbitrary node that has no parents.
      def root
        roots.first
      end

      # There is no default depth limit. This might be crazy-big, depending
      # on your tree shape. Hash huge trees at your own peril!
      def hash_tree(options = {})
        build_hash_tree(hash_tree_scope(options[:limit_depth]))
      end

      def leaves
        s = joins(<<-SQL)
          INNER JOIN (
            SELECT ancestor_id
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY 1
            HAVING MAX(#{_ct.quoted_hierarchy_table_name}.generations) = 0
          ) AS leaves ON (#{_ct.quoted_table_name}.#{primary_key} = leaves.ancestor_id)
        SQL
        _ct.scope_with_order(s.readonly(false))
      end

      # Renders the given scope as a DOT digraph, suitable for rendering by Graphviz
      def to_dot_digraph(tree_scope)
        id_to_instance = tree_scope.inject({}) { |h, ea| h[ea.id] = ea; h }
        output = StringIO.new
        output << "digraph G {\n"
        tree_scope.each do |ea|
          if id_to_instance.has_key? ea._ct_parent_id
            output << "  #{ea._ct_parent_id} -> #{ea._ct_id}\n"
          end
          output << "  #{ea._ct_id} [label=\"#{ea.to_digraph_label}\"]\n"
        end
        output << "}\n"
        output.string
      end
    end
  end
end

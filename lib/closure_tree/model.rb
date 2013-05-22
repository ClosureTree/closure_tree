require 'active_support/concern'

module ClosureTree
  module Model
    extend ActiveSupport::Concern

    included do
      validate :ct_validate
      before_save :ct_before_save
      after_save :ct_after_save
      before_destroy :ct_before_destroy

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
      parent_id.nil?
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
      _ct.scope_with_order(_ct.base_class.where(_ct.parent_column_sym => parent_id))
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

    # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+.
    def find_by_path(path)
      return self if path.empty?
      parent_constraint = "#{_ct.quoted_parent_column_name} = #{_ct.quote(id)}"
      self.class.ct_scoped_to_path(path, parent_constraint).first
    end

    # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+
    def find_or_create_by_path(path, attributes = {}, find_before_lock = true)
      (find_before_lock && find_by_path(path)) || begin
        ct_with_advisory_lock do
          subpath = path.is_a?(Enumerable) ? path.dup : [path]
          child_name = subpath.shift
          return self unless child_name
          child = transaction do
            attrs = {_ct.name_sym => child_name}
            attrs[:type] = self.type if _ct.subclass? && _ct.has_type?
            self.children.where(attrs).first || begin
              child = self.class.new(attributes.merge(attrs))
              self.children << child
              child
            end
          end
          child.find_or_create_by_path(subpath, attributes, false)
        end
      end
    end

    def find_all_by_generation(generation_level)
      s = _ct.base_class.joins(<<-SQL)
        INNER JOIN (
          SELECT descendant_id
          FROM #{_ct.quoted_hierarchy_table_name}
          WHERE ancestor_id = #{_ct.quote(self.id)}
          GROUP BY 1
          HAVING MAX(#{_ct.quoted_hierarchy_table_name}.generations) = #{generation_level.to_i}
        ) AS descendants ON (#{_ct.quoted_table_name}.#{_ct.base_class.primary_key} = descendants.descendant_id)
      SQL
      _ct.scope_with_order(s)
    end

    def hash_tree_scope(limit_depth = nil)
      scope = self_and_descendants
      if limit_depth
        scope.where("#{_ct.quoted_hierarchy_table_name}.generations <= #{limit_depth - 1}")
      else
        scope
      end
    end

    def hash_tree(options = {})
      self.class.build_hash_tree(hash_tree_scope(options[:limit_depth]))
    end

    def parent_id
      read_attribute(_ct.parent_column_sym)
    end

    def ct_validate
      if changes[_ct.parent_column_name] &&
        parent.present? &&
        parent.self_and_ancestors.include?(self)
        errors.add(_ct.parent_column_sym, "You cannot add an ancestor as a descendant")
      end
    end

    def ct_before_save
      @was_new_record = new_record?
      true # don't cancel the save
    end

    def ct_after_save
      rebuild! if changes[_ct.parent_column_name] || @was_new_record
      @was_new_record = false # we aren't new anymore.
      true # don't cancel anything.
    end

    def rebuild!
      ct_with_advisory_lock do
        delete_hierarchy_references unless @was_new_record
        hierarchy_class.create!(:ancestor => self, :descendant => self, :generations => 0)
        unless root?
          sql = <<-SQL
            INSERT INTO #{_ct.quoted_hierarchy_table_name}
              (ancestor_id, descendant_id, generations)
            SELECT x.ancestor_id, #{_ct.quote(id)}, x.generations + 1
            FROM #{_ct.quoted_hierarchy_table_name} x
            WHERE x.descendant_id = #{_ct.quote(self.parent_id)}
          SQL
          _ct.connection.execute sql.strip
        end
        children.each { |c| c.rebuild! }
      end
    end

    def ct_before_destroy
      delete_hierarchy_references
      if _ct.options[:dependent] == :nullify
        children.each { |c| c.rebuild! }
      end
    end

    def delete_hierarchy_references
      # The crazy double-wrapped sub-subselect works around MySQL's limitation of subselects on the same table that is being mutated.
      # It shouldn't affect performance of postgresql.
      # See http://dev.mysql.com/doc/refman/5.0/en/subquery-errors.html
      # Also: PostgreSQL doesn't support INNER JOIN on DELETE, so we can't use that.
      _ct.connection.execute <<-SQL
        DELETE FROM #{_ct.quoted_hierarchy_table_name}
        WHERE descendant_id IN (
          SELECT DISTINCT descendant_id
          FROM (SELECT descendant_id
            FROM #{_ct.quoted_hierarchy_table_name}
            WHERE ancestor_id = #{_ct.quote(id)}
          ) AS x )
          OR descendant_id = #{_ct.quote(id)}
      SQL
    end

    def without_self(scope)
      scope.without(self)
    end

    module ClassMethods
      def roots
        _ct.scope_with_order(where(_ct.parent_column_name => nil))
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
        _ct.scope_with_order(s)
      end

      # Rebuilds the hierarchy table based on the parent_id column in the database.
      # Note that the hierarchy table will be truncated.
      def rebuild!
        ct_with_advisory_lock do
          hierarchy_class.delete_all # not destroy_all -- we just want a simple truncate.
          roots.each { |n| n.send(:rebuild!) } # roots just uses the parent_id column, so this is safe.
        end
        nil
      end

      def find_all_by_generation(generation_level)
        s = joins(<<-SQL)
          INNER JOIN (
            SELECT #{primary_key} as root_id
            FROM #{_ct.quoted_table_name}
            WHERE #{_ct.quoted_parent_column_name} IS NULL
          ) AS roots ON (1 = 1)
          INNER JOIN (
            SELECT ancestor_id, descendant_id
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY 1, 2
            HAVING MAX(generations) = #{generation_level.to_i}
          ) AS descendants ON (
            #{_ct.quoted_table_name}.#{primary_key} = descendants.descendant_id
            AND roots.root_id = descendants.ancestor_id
          )
        SQL
        _ct.scope_with_order(s)
      end

      # Find the node whose +ancestry_path+ is +path+
      def find_by_path(path)
        parent_constraint = "#{_ct.quoted_parent_column_name} IS NULL"
        ct_scoped_to_path(path, parent_constraint).first
      end

      def ct_scoped_to_path(path, parent_constraint)
        path = path.is_a?(Enumerable) ? path.dup : [path]
        scope = where(_ct.name_sym => path.last).readonly(false)
        path[0..-2].reverse.each_with_index do |ea, idx|
          subtable = idx == 0 ? _ct.quoted_table_name : "p#{idx - 1}"
          scope = scope.joins(<<-SQL)
            INNER JOIN #{_ct.quoted_table_name} AS p#{idx} ON p#{idx}.id = #{subtable}.#{_ct.parent_column_name}
          SQL
          scope = scope.where("p#{idx}.#{_ct.quoted_name_column} = #{_ct.quote(ea)}")
        end
        root_table_name = path.size > 1 ? "p#{path.size - 2}" : _ct.quoted_table_name
        scope.where("#{root_table_name}.#{parent_constraint}")
      end

      # Find or create nodes such that the +ancestry_path+ is +path+
      def find_or_create_by_path(path, attributes = {})
        find_by_path(path) || begin
          subpath = path.dup
          root_name = subpath.shift
          ct_with_advisory_lock do
            # shenanigans because find_or_create can't infer we want the same class as this:
            # Note that roots will already be constrained to this subclass (in the case of polymorphism):
            root = roots.where(_ct.name_sym => root_name).first
            root ||= create!(attributes.merge(_ct.name_sym => root_name))
            root.find_or_create_by_path(subpath, attributes)
          end
        end
      end

      def hash_tree_scope(limit_depth = nil)
        # Deepest generation, within limit, for each descendant
        # NOTE: Postgres requires HAVING clauses to always contains aggregate functions (!!)
        generation_depth = <<-SQL
          INNER JOIN (
            SELECT descendant_id, MAX(generations) as depth
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY descendant_id
            #{limit_depth ? "HAVING MAX(generations) <= #{limit_depth - 1}" : ""}
          ) AS generation_depth
            ON #{_ct.quoted_table_name}.#{primary_key} = generation_depth.descendant_id
        SQL
        _ct.scope_with_order(joins(generation_depth), "generation_depth.depth")
      end

      # Builds nested hash structure using the scope returned from the passed in scope
      def build_hash_tree(tree_scope)
        tree = ActiveSupport::OrderedHash.new
        id_to_hash = {}

        tree_scope.each do |ea|
          h = id_to_hash[ea.id] = ActiveSupport::OrderedHash.new
          if ea.root? || tree.empty? # We're at the top of the tree.
            tree[ea] = h
          else
            id_to_hash[ea.parent_id][ea] = h
          end
        end
        tree
      end
    end
  end
end

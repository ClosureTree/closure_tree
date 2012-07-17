module ClosureTree
  module ActsAsTree
    def acts_as_tree(options = {})

      class_attribute :closure_tree_options

      self.closure_tree_options = {
        :parent_column_name => 'parent_id',
        :dependent => :nullify, # or :destroy or :delete_all -- see the README
        :name_column => 'name'
      }.merge(options)

      raise IllegalArgumentException, "name_column can't be 'path'" if closure_tree_options[:name_column] == 'path'

      include ClosureTree::Columns
      extend ClosureTree::Columns

      # Auto-inject the hierarchy table
      # See https://github.com/patshaughnessy/class_factory/blob/master/lib/class_factory/class_factory.rb
      class_attribute :hierarchy_class
      self.hierarchy_class = Object.const_set hierarchy_class_name, Class.new(ActiveRecord::Base)

      self.hierarchy_class.class_eval <<-RUBY
        belongs_to :ancestor, :class_name => "#{ct_class.to_s}"
        belongs_to :descendant, :class_name => "#{ct_class.to_s}"
        attr_accessible :ancestor, :descendant, :generations
        def ==(comparison_object)
          comparison_object.instance_of?(self.class) &&
          self.attributes == comparison_object.attributes
        end
        alias :eql? :==
      RUBY

      unless ct_order_option.nil?
        include ClosureTree::DeterministicOrdering
        include ClosureTree::DeterministicNumericOrdering if ct_order_is_numeric
      end

      include ClosureTree::Model

      validate :ct_validate
      before_save :ct_before_save
      after_save :ct_after_save
      before_destroy :ct_before_destroy

      belongs_to :parent,
        :class_name => ct_class.to_s,
        :foreign_key => parent_column_name

      has_many :children, ct_order_param.merge(
        :class_name => ct_class.to_s,
          :foreign_key => parent_column_name,
          :dependent => closure_tree_options[:dependent]
      )

      has_many :ancestor_hierarchies,
        :class_name => hierarchy_class_name,
        :foreign_key => "descendant_id",
        :order => "generations asc",
        :dependent => :destroy

      has_many :self_and_ancestors,
        :through => :ancestor_hierarchies,
        :source => :ancestor,
        :order => "generations asc"

      has_many :descendant_hierarchies,
        :class_name => hierarchy_class_name,
        :foreign_key => "ancestor_id",
        :order => "generations asc",
        :dependent => :destroy
        # TODO: FIXME: this collection currently ignores sort_order
        # (because the quoted_table_named would need to be joined in to get to the order column)

      has_many :self_and_descendants,
        :through => :descendant_hierarchies,
        :source => :descendant,
        :order => ct_with_order("generations asc")

      def self.roots
        where(parent_column_name => nil)
      end

      def self.leaves
        s = where("#{quoted_table_name}.#{primary_key} IN
        (SELECT ancestor_id
         FROM #{quoted_hierarchy_table_name}
         GROUP BY 1
         HAVING MAX(generations) = 0)")
        if ct_order_option
          s.order(ct_order_option)
        end
        s
      end
    end
  end

  module Model
    extend ActiveSupport::Concern

    # Returns true if this node has no parents.
    def root?
      ct_parent_id.nil?
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
      self_and_ancestors.where(parent_column_name.to_sym => nil).first
    end

    def leaves
      return [self] if leaf?
      self.class.leaves.where(<<-SQL
#{quoted_table_name}.#{self.class.primary_key} IN (
          SELECT descendant_id
          FROM #{quoted_hierarchy_table_name}
          WHERE ancestor_id = #{id})
      SQL
      )
    end

    def depth
      ancestors.size
    end

    alias :level :depth

    def ancestors
      without_self(self_and_ancestors)
    end

    # Returns an array, root first, of self_and_ancestors' values of the +to_s_column+, which defaults
    # to the +name_column+.
    # (so child.ancestry_path == +%w{grandparent parent child}+
    def ancestry_path(to_s_column = name_column)
      self_and_ancestors.reverse.collect { |n| n.send to_s_column.to_sym }
    end

    def descendants
      without_self(self_and_descendants)
    end

    def self_and_siblings
      s = self.class.scoped.where(:parent_id => parent)
      s = s.order(quoted_order_column) if quoted_order_column
      s
    end

    def siblings
      without_self(self_and_siblings)
    end

    # This supports adding siblings to root nodes:
    def add_sibling(sibling_node, save_immediately = true)
      sibling_node.parent = self.parent
      sibling_node.save! if save_immediately
    end

    # Alias for appending to the children collection.
    # You can also add directly to the children collection, if you'd prefer.
    def add_child(child_node)
      children << child_node
      child_node
    end

    # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+.
    def find_by_path(path)
      path = path.is_a?(Enumerable) ? path.dup : [path]
      node = self
      while !path.empty? && node
        node = node.children.send("find_by_#{name_column}", path.shift)
      end
      node
    end

    # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+
    def find_or_create_by_path(path, attributes = {})
      path = path.is_a?(Enumerable) ? path.dup : [path]
      node = self
      attrs = {}
      attrs[:type] = self.type if ct_subclass? && ct_has_type?
      path.each do |name|
        attrs[name_sym] = name
        child = node.children.where(attrs).first
        unless child
          child = self.class.new(attributes.merge(attrs))
          node.children << child
        end
        node = child
      end
      node
    end

    protected

    def ct_validate
      if changes[parent_column_name] &&
        parent.present? &&
        parent.self_and_ancestors.include?(self)
        errors.add(parent_column_sym, "You cannot add an ancestor as a descendant")
      end
    end

    def ct_before_save
      @was_new_record = new_record?
      true # don't cancel the save
    end

    def ct_after_save
      rebuild! if changes[parent_column_name] || @was_new_record
    end

    def rebuild!
      delete_hierarchy_references unless @was_new_record
      hierarchy_class.create!(:ancestor => self, :descendant => self, :generations => 0)
      unless root?
        connection.execute <<-SQL
          INSERT INTO #{quoted_hierarchy_table_name}
            (ancestor_id, descendant_id, generations)
          SELECT x.ancestor_id, #{id}, x.generations + 1
          FROM #{quoted_hierarchy_table_name} x
          WHERE x.descendant_id = #{self.ct_parent_id}
        SQL
      end
      children.each { |c| c.rebuild! }
    end

    def ct_before_destroy
      delete_hierarchy_references
      if closure_tree_options[:dependent] == :nullify
        children.each { |c| c.rebuild! }
      end
    end

    def delete_hierarchy_references
      # The crazy double-wrapped sub-subselect works around MySQL's limitation of subselects on the same table that is being mutated.
      # It shouldn't affect performance of postgresql.
      # See http://dev.mysql.com/doc/refman/5.0/en/subquery-errors.html
      connection.execute <<-SQL
        DELETE FROM #{quoted_hierarchy_table_name}
        WHERE descendant_id IN (
          SELECT DISTINCT descendant_id
          FROM ( SELECT descendant_id
            FROM #{quoted_hierarchy_table_name}
            WHERE ancestor_id = #{id}
          ) AS x )
          OR descendant_id = #{id}
      SQL
    end

    def without_self(scope)
      scope.where(["#{quoted_table_name}.#{self.class.primary_key} != ?", self])
    end

    def ct_parent_id
      send(parent_column_name)
    end

    # TODO: _parent_id will be removed in the next major version
    alias :_parent_id :ct_parent_id

    module ClassMethods

      # Returns an arbitrary node that has no parents.
      def root
        roots.first
      end

      # Rebuilds the hierarchy table based on the parent_id column in the database.
      # Note that the hierarchy table will be truncated.
      def rebuild!
        hierarchy_class.delete_all # not destroy_all -- we just want a simple truncate.
        roots.each { |n| n.send(:rebuild!) } # roots just uses the parent_id column, so this is safe.
        nil
      end

      # Find the node whose +ancestry_path+ is +path+
      def find_by_path(path)
        root = roots.send("find_by_#{name_column}", path.shift)
        root.try(:find_by_path, path)
      end

      # Find or create nodes such that the +ancestry_path+ is +path+
      def find_or_create_by_path(path, attributes = {})
        name = path.shift
        # shenanigans because find_or_create can't infer we want the same class as this:
        # Note that roots will already be constrained to this subclass (in the case of polymorphism):
        root = roots.send("find_by_#{name_column}", name)
        if root.nil?
          root = create!(attributes.merge(name_sym => name))
        end
        root.find_or_create_by_path(path, attributes)
      end
    end
  end

  # Mixed into both classes and instances to provide easy access to the column names
  module Columns

    def parent_column_name
      closure_tree_options[:parent_column_name]
    end

    def parent_column_sym
      parent_column_name.to_sym
    end

    def has_name?
      ct_class.new.attributes.include? closure_tree_options[:name_column]
    end

    def name_column
      closure_tree_options[:name_column]
    end

    def name_sym
      name_column.to_sym
    end

    def hierarchy_table_name
      # We need to use the table_name, not ct_class.to_s.demodulize, because they may have overridden the table name
      closure_tree_options[:hierarchy_table_name] || ct_table_name.singularize + "_hierarchies"
    end

    def hierarchy_class_name
      hierarchy_table_name.singularize.camelize
    end

    def quoted_hierarchy_table_name
      connection.quote_column_name hierarchy_table_name
    end

    def quoted_parent_column_name
      connection.quote_column_name parent_column_name
    end

    def order_option
      closure_tree_options[:order]
    end

    def ct_class
      (self.is_a?(Class) ? self : self.class)
    end

    def ct_subclass?
      ct_class != ct_class.base_class
    end

    def ct_attribute_names
      @ct_attr_names ||= ct_class.new.attributes.keys - ct_class.protected_attributes.to_a
    end

    def ct_has_type?
      ct_attribute_names.include? 'type'
    end

    def ct_table_name
      ct_class.table_name
    end

    def quoted_table_name
      connection.quote_column_name ct_table_name
    end
  end

  module DeterministicOrdering
    def order_column
      o = order_option
      o.split(' ', 2).first if o
    end

    def require_order_column
      raise ":order value, '#{order_option}', isn't a column" if order_column.nil?
    end

    def order_column_sym
      require_order_column
      order_column.to_sym
    end

    def order_value
      send(order_column_sym)
    end

    def order_value=(new_order_value)
      require_order_column
      send("#{order_column}=".to_sym, new_order_value)
    end

    def quoted_order_column
      require_order_column
      "#{quoted_table_name}.#{connection.quote_column_name(order_column)}"
    end

    def siblings_before
      siblings.where(["#{quoted_order_column} < ?", order_value])
    end

    def siblings_after
      siblings.where(["#{quoted_order_column} > ?", order_value])
    end
  end

  module DeterministicNumericOrdering
    def append_sibling(sibling_node, use_update_all = true)
      sibling_node.ct_order = self.sort_order.to_i - 1
      # We need to decr the before_siblings to make room for sibling_node:
      if use_update_all
        update_all(["#{ct_order_column} = #{ct_order_column} - 1", "updated_at = now()"],
          "#{quoted_parent_column_name} = #{ct_parent_id} AND #{ct_order_column} <= #{sibling_node.ct_order}")
      else
        last_value = sibling_node.ct_order
        siblings_before.reverse.each do |ea|
          last_value -= 1
          ea.ct_order = last_value
          ea.save!
        end
      end
      sibling_node.parent = self.parent
      sibling_node.save!
    end

    def prepend_sibling(sibling_node, use_update_all = true)
      sibling_node.ct_order = self.sort_order.to_i + 1
      # We need to incr the before_siblings to make room for sibling_node:
      if use_update_all
        update_all(["#{ct_order_column} = #{ct_order_column} + 1", "updated_at = now()"],
          "#{quoted_parent_column_name} = #{ct_parent_id} AND #{ct_order_column} >= #{sibling_node.ct_order}")
      else
        last_value = sibling_node.ct_order
        siblings_after.each do |ea|
          last_value += 1
          ea.ct_order = last_value
          ea.save!
        end
      end
      sibling_node.parent = self.parent
      sibling_node.save!
    end
  end
end

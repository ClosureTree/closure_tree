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
      RUBY

      include ClosureTree::Model

      before_destroy :acts_as_tree_before_destroy
      before_save :acts_as_tree_before_save
      after_save :acts_as_tree_after_save

      belongs_to :parent,
        :class_name => ct_class.to_s,
        :foreign_key => parent_column_name

      has_many :children,
        :class_name => ct_class.to_s,
        :foreign_key => parent_column_name,
        :dependent => closure_tree_options[:dependent]

      has_and_belongs_to_many :self_and_ancestors,
        :class_name => ct_class.to_s,
        :join_table => hierarchy_table_name,
        :foreign_key => "descendant_id",
        :association_foreign_key => "ancestor_id",
        :order => "generations asc"

      has_and_belongs_to_many :self_and_descendants,
        :class_name => ct_class.to_s,
        :join_table => hierarchy_table_name,
        :foreign_key => "ancestor_id",
        :association_foreign_key => "descendant_id",
        :order => "generations asc"

      scope :roots, where(parent_column_name => nil)

      scope :leaves, where(" #{quoted_table_name}.#{primary_key} IN
        (SELECT ancestor_id
         FROM #{quoted_hierarchy_table_name}
         GROUP BY 1
         HAVING MAX(generations) = 0)")
    end
  end

  module Model
    extend ActiveSupport::Concern
    module InstanceMethods

      # Returns true if this node has no parents.
      def root?
        parent.nil?
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
        root? ? self : ancestors.last
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

      def level
        ancestors.size
      end

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
        self.class.scoped.where(:parent => parent)
      end

      def siblings
        without_self(self_and_siblings)
      end

      # Alias for appending to the children collection.
      # You can also add directly to the children collection, if you'd prefer.
      def add_child(child_node)
        children << child_node
        child_node
      end

      # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+.
      def find_by_path(path)
        path = [path] unless path.is_a? Enumerable
        node = self
        while (!path.empty? && node)
          node = node.children.send("find_by_#{name_column}", path.shift)
        end
        node
      end

      # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+
      def find_or_create_by_path(path, attributes = {})
        path = [path] unless path.is_a? Enumerable
        node = self
        attrs = {}
        attrs[:type] = self.type if ct_subclass? && ct_has_type?
        path.each do |name|
          attrs[name_sym] = name
          child = node.children.where(attrs).first
          unless child
            child = self.class.new(attributes.merge attrs)
            node.children << child
          end
          node = child
        end
        node
      end

      protected

      def acts_as_tree_before_save
        @was_new_record = new_record?
        if changes[parent_column_name] &&
          parent.present? &&
          parent.self_and_ancestors.include?(self)
          # TODO: raise Ouroboros or Philip J. Fry error:
          raise ActiveRecord::ActiveRecordError "You cannot add an ancestor as a descendant"
        end
      end

      def acts_as_tree_after_save
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
            WHERE x.descendant_id = #{self._parent_id}
          SQL
        end
        children.each { |c| c.rebuild! }
      end

      def acts_as_tree_before_destroy
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

      def _parent_id
        send(parent_column_name)
      end
    end

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
end

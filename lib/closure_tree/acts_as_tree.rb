module ClosureTree #:nodoc:
  module ActsAsTree #:nodoc:
    def acts_as_tree options = {}

      class_attribute :closure_tree_options
      self.closure_tree_options = {
        :parent_column_name => 'parent_id',
        :dependent => :delete_all, # or :destroy
        :hierarchy_table_suffix => '_hierarchies',
        :name_column => 'name'
      }.merge(options)

      include ClosureTree::Columns
      extend ClosureTree::Columns

      # Auto-inject the hierarchy table
      # See https://github.com/patshaughnessy/class_factory/blob/master/lib/class_factory/class_factory.rb
      class_attribute :hierarchy_class
      self.hierarchy_class = Object.const_set hierarchy_class_name, Class.new(ActiveRecord::Base)

      self.hierarchy_class.class_eval <<-RUBY
        belongs_to :ancestor, :class_name => "#{base_class.to_s}"
        belongs_to :descendant, :class_name => "#{base_class.to_s}"
      RUBY

      include ClosureTree::Model

      belongs_to :parent, :class_name => base_class.to_s,
                 :foreign_key => parent_column_name

      has_many :children,
               :class_name => base_class.to_s,
               :foreign_key => parent_column_name,
               :before_add => :add_child

      has_many :ancestors_hierarchy,
               :class_name => hierarchy_class_name,
               :foreign_key => "descendant_id"

      has_many :ancestors, :through => :ancestors_hierarchy,
               :order => "generations asc"

      has_many :descendants_hierarchy,
               :class_name => hierarchy_class_name,
               :foreign_key => "ancestor_id"

      has_many :descendants, :through => :descendants_hierarchy,
               :order => "generations asc"

      scope :roots, where(parent_column_name => nil)

      scope :leaves, includes(:descendants_hierarchy).where("#{hierarchy_table_name}.descendant_id is null")
    end
  end

  module Model
    extend ActiveSupport::Concern
    module InstanceMethods
      def parent_id
        self[parent_column_name]
      end

      def parent_id= new_parent_id
        self[parent_column_name] = new_parent_id
      end

      # Returns true if this node has no parents.
      def root?
        parent_id.nil?
      end

      # Returns true if this node has no children.
      def leaf?
        children.empty?
      end

      def leaves
        self.class.scoped.includes(:descendants_hierarchy).where("#{hierarchy_table_name}.descendant_id is null and #{hierarchy_table_name}.ancestor_id = #{id}")
      end

      # Returns true if this node has a parent, and is not a root.
      def child?
        !parent_id.nil?
      end

      def level
        ancestors.size
      end

      def self_and_ancestors
        [self].concat ancestors.to_a
      end

      # Returns an array, root first, of self_and_ancestors' values of the +to_s_column+, which defaults
      # to the +name_column+.
      # (so child.ancestry_path == +%w{grandparent parent child}+
      def ancestry_path to_s_column = name_column
        self_and_ancestors.reverse.collect { |n| n.send to_s_column.to_sym }
      end

      def self_and_descendants
        [self].concat descendants.to_a
      end

      def self_and_siblings
        self.class.scoped.where(:parent_id => parent_id)
      end

      def siblings
        without_self(self_and_siblings)
      end

      # You must use this method, or add child nodes to the +children+ association, to
      # make the hierarchy table stay consistent.
      def add_child child_node
        child_node.update_attribute :parent_id, self.id
        self_and_ancestors.inject(1) do |gen, ancestor|
          hierarchy_class.create!(:ancestor => ancestor, :descendant => child_node, :generations => gen)
          gen + 1
        end
        nil
      end

      def move_to_child_of new_parent
        connection.execute <<-SQL
          DELETE FROM #{quoted_hierarchy_table_name}
          WHERE descendant_id = #{child_node.id}
        SQL
        new_parent.add_child self
      end

      # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+.
      # If the first argument is a symbol, it will be used as the column to search by
      def find_by_path *path
        _find_or_create_by_path "find", path
      end

      # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+
      def find_or_create_by_path *path
        _find_or_create_by_path "find_or_create", path
      end

      protected

      def _find_or_create_by_path method_prefix, path
        to_s_column = path.first.is_a?(Symbol) ? path.shift.to_s : name_column
        path.flatten!
        node = self
        while (s = path.shift and node)
          node = node.children.send("#{method_prefix}_by_#{to_s_column}".to_sym, s)
        end
        node
      end

      def without_self(scope)
        scope.where(["#{quoted_table_name}.#{self.class.primary_key} != ?", self])
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
        connection.execute <<-SQL
          DELETE FROM #{quoted_hierarchy_table_name}
        SQL
        roots.each { |n| rebuild_node_and_children n }
        nil
      end

      # Find the node whose +ancestry_path+ is +path+
      # If the first argument is a symbol, it will be used as the column to search by
      def find_by_path *path
        to_s_column = path.first.is_a?(Symbol) ? path.shift.to_s : name_column
        path.flatten!
        self.where(to_s_column => path.last).each do |n|
          return n if path == n.ancestry_path(to_s_column)
        end
        nil
      end

      # Find or create nodes such that the +ancestry_path+ is +path+
      def find_or_create_by_path *path
        # short-circuit if we can:
        n = find_by_path path
        return n if n

        column_sym = path.first.is_a?(Symbol) ? path.shift : name_sym
        path.flatten!
        s = path.shift
        node = roots.where(column_sym => s).first
        node = create!(column_sym => s) unless node
        node.find_or_create_by_path column_sym, path
      end

      private
      def rebuild_node_and_children node
        node.parent.add_child node if node.parent
        node.children.each { |child| rebuild_node_and_children child }
      end
    end
  end

  # Mixed into both classes and instances to provide easy access to the column names
  module Columns

    protected

    def parent_column_name
      closure_tree_options[:parent_column_name]
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
      ct_table_name + closure_tree_options[:hierarchy_table_suffix]
    end

    def hierarchy_class_name
      hierarchy_table_name.singularize.camelize
    end

    def quoted_hierarchy_table_name
      connection.quote_column_name hierarchy_table_name
    end

    def scope_column_names
      Array closure_tree_options[:scope]
    end

    def quoted_parent_column_name
      connection.quote_column_name parent_column_name
    end

    def ct_class
      (self.is_a?(Class) ? self : self.class)
    end

    def ct_table_name
      ct_class.table_name
    end

    def quoted_table_name
      connection.quote_column_name ct_table_name
    end

  end
end

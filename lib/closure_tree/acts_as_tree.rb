module ClosureTree #:nodoc:
  module ActsAsTree #:nodoc:
    def acts_as_tree options = {}

      class_attribute :closure_tree_options
      self.closure_tree_options = {
        :parent_column_name => 'parent_id',
        :dependent => :delete_all, # or :destroy
        :hierarchy_table_suffix => '_hierarchies'
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

      def root?
        parent_id.nil?
      end

      def leaf?
        children.empty?
      end

      def leaves
        self.class.scoped.includes(:descendants_hierarchy).where("#{hierarchy_table_name}.descendant_id is null and #{hierarchy_table_name}.ancestor_id = #{id}")
      end

      # Returns true is this is a child node
      def child?
        !parent_id.nil?
      end

      def level
        ancestors.count
      end

      def self_and_ancestors
        [self].concat ancestors.to_a
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

      protected

      def without_self(scope)
        scope.where(["#{quoted_table_name}.#{self.class.primary_key} != ?", self])
      end

    end

    module ClassMethods
      def root
        roots.first
      end

      def rebuild!
        connection.execute <<-SQL
          DELETE FROM #{quoted_hierarchy_table_name}
        SQL
        roots.each { |n| rebuild_node_and_children n }
        nil
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

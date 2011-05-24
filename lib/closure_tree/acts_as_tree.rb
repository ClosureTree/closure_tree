module ClosureTree #:nodoc:
  module ActsAsTree #:nodoc:
    def acts_as_tree options = {}

      class_attribute :closure_tree_options
      self.closure_tree_options = {
        :parent_column_name => 'parent_id',
        :dependent => :delete_all, # or :destroy
        :hierarchy_table_suffix => '_hierarchy'
      }.merge(options)

      include ClosureTree::Columns
      extend ClosureTree::Columns
      include ClosureTree::Model

      belongs_to :parent, :class_name => base_class.to_s,
                 :foreign_key => parent_column_name

      has_many :children,
               :class_name => base_class.to_s,
               :foreign_key => parent_column_name,
               :before_add => :add_child

      scope :roots, where(parent_column_name => nil)

#      scope :leaves
#      scope :leaves, where("#{quoted_right_column_name} - #{quoted_left_column_name} = 1").order(quoted_left_column_name)

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

      # Returns true is this is a child node
      def child?
        !parent_id.nil?
      end

      def ancestor_ids_with_generations
        @ancestor_ids_with_generations ||= begin
          ancestors = connection.select_rows <<-SQL
            select ancestor_id, generations
            from #{quoted_hierarchy_table_name}
            where descendant_id = #{self.id}
          SQL
          ancestors << [self.id, 0]
        end
      end

      def add_child child_node
        child_node.parent_id = self.id
        ancestor_ids_with_generations.each do |ancestor_id, generations|
          # TODO: should the hierarchy table be modeled by ActiveRecord?
          connection.execute <<-SQL
            INSERT INTO #{quoted_hierarchy_table_name}
              (ancestor_id, descendant_id, generations)
            VALUES
              (#{ancestor_id}, #{child_node.id}, #{generations + 1})
          SQL
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

    end

    module ClassMethods
      def root
        roots.first
      end

      def rebuild!
        connection.execute <<-SQL
          DELETE FROM #{quoted_hierarchy_table_name}
        SQL
        build_node_hier = lambda do |node|
          node.parent.add_child node if node.parent
          node.children.each { |child| build_node_hier child }
        end
        roots.each do |node|
          build_node_hier node
        end
      end
    end
  end

  # Mixed into both classes and instances to provide easy access to the column names
  module Columns
    def parent_column_name
      closure_tree_options[:parent_column_name]
    end

    def hierarchy_table_name
      (self.is_a?(Class) ? self : self.class).table_name + closure_tree_options[:hierarchy_table_suffix]
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
  end
end

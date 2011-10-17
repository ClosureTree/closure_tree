module ClosureTree
  module ActsAsTree
    def acts_as_tree(options = {})

      class_attribute :closure_tree_options

      self.closure_tree_options = {
        :parent_column_name => 'parent_id',
        :dependent => nil, # or :destroy or :delete_all -- see the README
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

      before_destroy :acts_as_tree_before_destroy

      belongs_to :parent,
        :class_name => base_class.to_s,
        :foreign_key => parent_column_name

      has_many :children,
        :class_name => base_class.to_s,
        :foreign_key => parent_column_name,
        :before_add => :add_child,
        :dependent => closure_tree_options[:dependent]

      has_and_belongs_to_many :self_and_ancestors,
        :class_name => base_class.to_s,
        :join_table => hierarchy_table_name,
        :foreign_key => "descendant_id",
        :association_foreign_key => "ancestor_id",
        :order => "generations asc"

      has_and_belongs_to_many :self_and_descendants,
        :class_name => base_class.to_s,
        :join_table => hierarchy_table_name,
        :foreign_key => "ancestor_id",
        :association_foreign_key => "descendant_id",
        :order => "generations asc"

      scope :roots, where(parent_column_name => nil)

      scope(:leaves, where(<<-SQL
        #{quoted_table_name}.#{primary_key} IN
          (SELECT ancestor_id from #{quoted_hierarchy_table_name}
           GROUP BY 1
           HAVING MAX(generations) = 0)
        SQL
      ))
    end
  end

  module Model
    extend ActiveSupport::Concern
    module InstanceMethods
      def parent_id
        self[parent_column_name]
      end

      def parent_id=(new_parent_id)
        self[parent_column_name] = new_parent_id
      end

      # Returns true if this node has no parents.
      def root?
        parent_id.nil?
      end

      # Returns self if +root?+ or the root ancestor
      def root
        root? ? self : ancestors.last
      end

      # Returns true if this node has no children.
      def leaf?
        children.empty?
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

      # Returns true if this node has a parent, and is not a root.
      def child?
        !parent_id.nil?
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
        self.class.scoped.where(:parent_id => parent_id)
      end

      def siblings
        without_self(self_and_siblings)
      end

      # You must use this method, or add child nodes to the +children+ association, to
      # make the hierarchy table stay consistent.
      # Note that an error will be raised if the child_node is already associated to this node.
      def add_child(child_node)
        if self_and_ancestors.include?(child_node)
          # TODO: raise Ouroboros or Philip J. Fry error:
          raise ActiveRecord::ActiveRecordError "You cannot add an ancestor as a descendant"
        end
        child_node.reparent(self)
        nil
      end

      # Note that object caches may be out of sync after calling this method.
      def reparent(new_parent)
        acts_as_tree_before_destroy if self_and_descendants.present?
        update_attribute :parent, new_parent
        rebuild!
      end

      def rebuild!
        hierarchy_class.create!(:ancestor => self, :descendant => self, :generations => 0)
        if parent_id
          connection.execute <<-SQL
            INSERT INTO #{quoted_hierarchy_table_name}
              (ancestor_id, descendant_id, generations)
            SELECT x.ancestor_id, #{id}, x.generations + 1
            FROM #{quoted_hierarchy_table_name} x
            WHERE x.descendant_id = #{parent_id}
          SQL
        end

        children.each { |child| child.rebuild! }
      end

      # NOTE that child nodes will need to be reloaded.
      def acts_as_tree_before_destroy
        # MySQL doesn't support subqueries in deletes, so we have to make a temp table. :-|
        doomed = "`doomed-#{SecureRandom.uuid}`"
        connection.execute <<-SQL
          CREATE TEMPORARY TABLE #{doomed} AS
            SELECT DISTINCT descendant_id
            FROM #{quoted_hierarchy_table_name}
            WHERE ancestor_id = #{id};
        SQL

        connection.execute <<-SQL
          DELETE FROM #{quoted_hierarchy_table_name}
          WHERE descendant_id IN (SELECT descendant_id FROM #{doomed})
            OR descendant_id = #{id}
        SQL

        connection.execute <<-SQL
          DROP TABLE #{doomed}
        SQL
      end

      # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+.
      # If the first argument is a symbol, it will be used as the column to search by
      def find_by_path(*path)
        recurse_path "find", *path
      end

      # Find a child node whose +ancestry_path+ minus self.ancestry_path is +path+
      def find_or_create_by_path(*path)
        recurse_path "find_or_create", *path
      end

      protected

      def recurse_path(method_prefix, *path)
        path = path.flatten
        to_s_column = path.first.is_a?(Symbol) ? path.shift.to_s : name_column
        node = self
        while ((s = path.shift) && node)
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
        in_tenacious_transaction do
          hierarchy_class.delete_all # not destroy_all -- we just want a simple truncate.
          roots.each { |n| n.rebuild! }
          nil
        end
      end

      # Find the node whose +ancestry_path+ is +path+
      # If the first argument is a symbol, it will be used as the column to search by
      def find_by_path(*path)
        path = path.flatten
        to_s_column = path.first.is_a?(Symbol) ? path.shift.to_s : name_column
        self.where(to_s_column => path.last).each do |n|
          return n if path == n.ancestry_path(to_s_column)
        end
        nil
      end

      # Find or create nodes such that the +ancestry_path+ is +path+
      def find_or_create_by_path(*path)
        # short-circuit if we can:
        n = find_by_path path
        return n if n

        path.flatten
        column_sym = path.first.is_a?(Symbol) ? path.shift : name_sym
        s = path.shift
        node = roots.where(column_sym => s).first
        node = create!(column_sym => s) unless node
        node.find_or_create_by_path column_sym, path
      end

      # From https://github.com/collectiveidea/awesome_nested_set:
      def in_tenacious_transaction(&block)
        retry_count = 0
        begin
          transaction(&block)
        rescue ActiveRecord::StatementInvalid => error
          raise unless connection.open_transactions.zero?
          raise unless error.message =~ /Deadlock found when trying to get lock|Lock wait timeout exceeded/
          raise unless retry_count < 10
          retry_count += 1
          logger.info "Deadlock detected on retry #{retry_count}, restarting transaction"
          sleep(rand(retry_count)*0.2) # Aloha protocol
          retry
        end
      end
    end
  end

  # Mixed into both classes and instances to provide easy access to the column names
  module Columns

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
      # We need to use the table_name, not ct_class.to_s.demodulize, because they may have overridden the table name
      closure_tree_options[:hierarchy_table_name] || ct_table_name.singularize + "_hierarchies"
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

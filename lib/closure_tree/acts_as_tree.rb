module ClosureTree #:nodoc:
  module ActsAsTree #:nodoc:
    def acts_as_tree(options = {})

      write_inheritable_attribute :closure_tree_options, {
        :parent_column_name => 'parent_id',
        :dependent => :delete_all, # or :destroy
        :hierarchy_table_name => '_hierarchy'
      }.merge(options)

      class_inheritable_reader :closure_tree_options
              include Columns
        extend Columns

      belongs_to :parent, :class_name => self.base_class.to_s,
          :foreign_key => parent_column_name,
          :counter_cache => options[:counter_cache]

    end
  end


      # Mixed into both classes and instances to provide easy access to the column names
      module Columns
        def parent_column_name
          acts_as_nested_set_options[:parent_column]
        end

        def scope_column_names
          Array(acts_as_nested_set_options[:scope])
        end

        def quoted_parent_column_name
          connection.quote_column_name(parent_column_name)
        end
      end
end

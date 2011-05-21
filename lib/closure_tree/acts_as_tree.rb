module ClosureTree #:nodoc:
  module ActsAsTree #:nodoc:
          def acts_as_tree(options = {})
        options = {
          :parent_column => 'parent_id',
          :dependent => :delete_all, # or :destroy
          :heirarchy_table_suffix => '_heirarchy'
        }.merge(options)

        if options[:scope].is_a?(Symbol) && options[:scope].to_s !~ /_id$/
          options[:scope] = "#{options[:scope]}_id".intern
        end

  end
end

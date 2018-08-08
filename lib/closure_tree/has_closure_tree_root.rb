module ClosureTree
  class MultipleRootError < StandardError; end
  class RootOrderingDisabledError < StandardError; end

  module HasClosureTreeRoot

    def has_closure_tree_root(assoc_name, options = {})
       options[:class_name] ||= assoc_name.to_s.sub(/\Aroot_/, "").classify
      options[:foreign_key] ||= self.name.underscore << "_id"

      has_one assoc_name, -> { where(parent: nil) }, options

      # Fetches the association, eager loading all children and given associations
      define_method("#{assoc_name}_including_tree") do |*args|
        reload = false
        reload = args.shift if args && (args.first == true || args.first == false)
        assoc_map = args
        assoc_map = [nil] if assoc_map.blank?

        # Memoize
        @closure_tree_roots ||= {}
        @closure_tree_roots[assoc_name] ||= {}
        unless reload
          if @closure_tree_roots[assoc_name].has_key?(assoc_map)
            return @closure_tree_roots[assoc_name][assoc_map]
          end
        end

        roots = options[:class_name].constantize.where(parent: nil, options[:foreign_key] => id).to_a

        return nil if roots.empty?

        if roots.size > 1
          raise MultipleRootError.new("#{self.class.name}: has_closure_tree_root requires a single root")
        end

        temp_root = roots.first
        root = nil
        id_hash = {}
        parent_col_id = temp_root.class._ct.options[:parent_column_name]

        # Lookup inverse belongs_to association reflection on target class.
        inverse = temp_root.class.reflections.values.detect do |r|
          r.macro == :belongs_to && r.klass == self.class
        end

        # Fetch all descendants in constant number of queries.
        # This is the last query-triggering statement in the method.
        temp_root.self_and_descendants.includes(*assoc_map).each do |node|
          id_hash[node.id] = node
          parent_node = id_hash[node[parent_col_id]]

          # Pre-assign parent association
          parent_assoc = node.association(:parent)
          parent_assoc.loaded!
          parent_assoc.target = parent_node

          # Pre-assign children association as empty for now,
          # children will be added in subsequent loop iterations
          children_assoc = node.association(:children)
          children_assoc.loaded!

          if parent_node
            parent_node.association(:children).target << node
          else
            # Capture the root we're going to use
            root = node
          end

          # Pre-assign inverse association back to this class, if it exists on target class.
          if inverse
            inverse_assoc = node.association(inverse.name)
            inverse_assoc.loaded!
            inverse_assoc.target = self
          end
        end

        @closure_tree_roots[assoc_name][assoc_map] = root
      end

      connection_pool.release_connection
    end
  end
end

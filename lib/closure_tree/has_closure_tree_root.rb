module ClosureTree
  class MultipleRootError < StandardError; end
  class RootOrderingDisabledError < StandardError; end

  module HasClosureTreeRoot
    def has_closure_tree_root(assoc_name, options = {})
      options[:class_name] ||= assoc_name.to_s.sub(/\Aroot_/, "").classify
      options[:foreign_key] ||= self.name.underscore << "_id"

      has_one assoc_name, -> { where(parent: nil) }, **options
      define_closure_tree_method(assoc_name, options, allow_multiple_roots: false)
      connection_pool.release_connection
    end

    def has_closure_tree_roots(assoc_name, options = {})
      options[:class_name] ||= assoc_name.to_s.sub(/\Aroots_/, "").classify
      options[:foreign_key] ||= self.name.underscore << "_id"

      has_many assoc_name, -> { where(parent: nil) }, **options
      define_closure_tree_method(assoc_name, options, allow_multiple_roots: true)
      connection_pool.release_connection
    end

    private

    def define_closure_tree_method(assoc_name, options, allow_multiple_roots: false)
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

        if roots.empty?
          return allow_multiple_roots ? [] : nil
        end

        unless allow_multiple_roots || roots.size <= 1
          raise MultipleRootError.new("#{self.class.name}: has_closure_tree_root requires a single root")
        end

        # Lookup inverse belongs_to association reflection on target class.
        inverse = roots.first.class.reflections.values.detect do |r|
          r.macro == :belongs_to && r.klass == self.class
        end

        # Fetch all descendants in constant number of queries.
        # This is the last query-triggering statement in the method.
        nodes_to_process = if allow_multiple_roots && roots.size > 0
          # For multiple roots, fetch all descendants at once to avoid N+1 queries
          root_ids = roots.map(&:id)
          klass = roots.first.class
          hierarchy_table = klass._ct.quoted_hierarchy_table_name
          
          # Get all descendants of all roots including the roots themselves
          # (generations 0 = self, > 0 = descendants)
          descendant_scope = klass.
            joins("INNER JOIN #{hierarchy_table} ON #{hierarchy_table}.descendant_id = #{klass.quoted_table_name}.#{klass.primary_key}").
            where("#{hierarchy_table}.ancestor_id IN (?)", root_ids).
            includes(*assoc_map).
            distinct
            
          descendant_scope
        else
          roots.first.self_and_descendants.includes(*assoc_map)
        end

        id_hash = {}
        parent_col_id = roots.first.class._ct.options[:parent_column_name]
        root = nil

        nodes_to_process.each do |node|
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
          elsif !allow_multiple_roots
            # Capture the root we're going to use (only for single root case)
            root = node
          end

          # Pre-assign inverse association back to this class, if it exists on target class.
          if inverse
            inverse_assoc = node.association(inverse.name)
            inverse_assoc.loaded!
            inverse_assoc.target = self
          end
        end

        result = allow_multiple_roots ? 
          roots.map { |root| id_hash[root.id] } : 
          root

        @closure_tree_roots[assoc_name][assoc_map] = result
      end
    end
  end
end

module ClosureTree
  class MultipleRootError < StandardError; end

  module HasClosureTreeRoot

    def has_closure_tree_root(assoc_name, options = {})
      options.assert_valid_keys(
        :class_name,
        :foreign_key
      )

      options[:class_name] ||= assoc_name.to_s.sub(/\Aroot_/, "").classify
      options[:foreign_key] ||= self.name.underscore << "_id"

      has_one assoc_name, -> { where(parent: nil) }, options

      # Fetches the association, eager loading all children and given associations
      define_method("#{assoc_name}_including_tree") do |assoc_map = nil|
        roots = options[:class_name].constantize.where(parent: nil, options[:foreign_key] => id).to_a

        return nil if roots.empty?

        if roots.size > 1
          raise MultipleRootError.new("#{self.class.name}: has_closure_tree_root requires a single root")
        end

        temp_root = roots.first
        root = nil
        id_hash = {}
        parent_col_id = temp_root.class._ct.options[:parent_column_name]

        temp_root.self_and_descendants.includes(assoc_map).each do |node|
          id_hash[node.id] = node
          parent_node = id_hash[node[parent_col_id]]

          # Preload parent association
          parent_assoc = node.association(:parent)
          parent_assoc.loaded!
          parent_assoc.target = parent_node

          # Preload children association as empty for now,
          # children will be added in subsequent loop iterations
          children_assoc = node.association(:children)
          children_assoc.loaded!

          if parent_node
            parent_node.association(:children).target << node
          else
            # Capture the root we're going to use
            root = node
          end
        end

        root
      end
    end
  end
end

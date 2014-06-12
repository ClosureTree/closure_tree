module ClosureTree
  module HashTree
    extend ActiveSupport::Concern

    def hash_tree_scope(limit_depth = nil)
      scope = self_and_descendants
      if limit_depth
        scope.where("#{_ct.quoted_hierarchy_table_name}.generations <= #{limit_depth - 1}")
      else
        scope
      end
    end

    def hash_tree(options = {})
      self.class.build_hash_tree(hash_tree_scope(options[:limit_depth]))
    end

    module ClassMethods

      # There is no default depth limit. This might be crazy-big, depending
      # on your tree shape. Hash huge trees at your own peril!
      def hash_tree(options = {})
        build_hash_tree(hash_tree_scope(options[:limit_depth]))
      end

      def hash_tree_scope(limit_depth = nil)
        # Deepest generation, within limit, for each descendant
        # NOTE: Postgres requires HAVING clauses to always contains aggregate functions (!!)
        having_clause = limit_depth ? "HAVING MAX(generations) <= #{limit_depth - 1}" : ''
        generation_depth = <<-SQL.strip_heredoc
          INNER JOIN (
            SELECT descendant_id, MAX(generations) as depth
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY descendant_id
            #{having_clause}
          ) AS generation_depth
            ON #{_ct.quoted_table_name}.#{primary_key} = generation_depth.descendant_id
        SQL
        _ct.scope_with_order(joins(generation_depth), "generation_depth.depth")
      end

      # Builds nested hash structure using the scope returned from the passed in scope
      def build_hash_tree(tree_scope)
        tree = ActiveSupport::OrderedHash.new
        id_to_hash = {}

        tree_scope.each do |ea|
          h = id_to_hash[ea.id] = ActiveSupport::OrderedHash.new
          if ea.root? || tree.empty? # We're at the top of the tree.
            tree[ea] = h
          else
            id_to_hash[ea._ct_parent_id][ea] = h
          end
        end
        tree
      end
    end
  end
end

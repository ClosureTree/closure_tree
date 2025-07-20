# frozen_string_literal: true

module ClosureTree
  module HashTreeSupport
    def default_tree_scope(scope, limit_depth = nil)
      # Deepest generation, within limit, for each descendant
      # NOTE: Postgres requires HAVING clauses to always contains aggregate functions (!!)

      # Get the hierarchy table for the scope's model class
      hierarchy_table_arel = if scope.respond_to?(:hierarchy_class)
                               scope.hierarchy_class.arel_table
                             elsif scope.klass.respond_to?(:hierarchy_class)
                               scope.klass.hierarchy_class.arel_table
                             else
                               hierarchy_table
                             end

      model_table_arel = scope.klass.arel_table

      # Build the subquery using Arel
      subquery = hierarchy_table_arel
                 .project(
                   hierarchy_table_arel[:descendant_id],
                   hierarchy_table_arel[:generations].maximum.as('depth')
                 )
                 .group(hierarchy_table_arel[:descendant_id])

      # Add HAVING clause if limit_depth is specified
      subquery = subquery.having(hierarchy_table_arel[:generations].maximum.lteq(limit_depth - 1)) if limit_depth

      generation_depth_alias = subquery.as('generation_depth')

      # Build the join
      join_condition = model_table_arel[scope.klass.primary_key].eq(generation_depth_alias[:descendant_id])

      join_source = model_table_arel
                    .join(generation_depth_alias)
                    .on(join_condition)
                    .join_sources

      scope_with_order(scope.joins(join_source), 'generation_depth.depth')
    end

    def hash_tree(tree_scope, limit_depth = nil)
      limited_scope = limit_depth ? tree_scope.where("#{quoted_hierarchy_table_name}.generations <= #{limit_depth - 1}") : tree_scope
      build_hash_tree(limited_scope)
    end

    # Builds nested hash structure using the scope returned from the passed in scope
    def build_hash_tree(tree_scope)
      tree = ActiveSupport::OrderedHash.new
      id_to_hash = {}

      tree_scope.each do |ea|
        h = id_to_hash[ea.id] = ActiveSupport::OrderedHash.new
        (id_to_hash[ea._ct_parent_id] || tree)[ea] = h
      end
      tree
    end
  end
end

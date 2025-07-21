# frozen_string_literal: true

module ClosureTree
  module ArelHelpers
    # Get model's arel table
    def model_table
      @model_table ||= model_class.arel_table
    end

    # Get hierarchy table from a model class
    # This method should be called from instance methods where hierarchy_class is available
    def hierarchy_table_for(model)
      if model.respond_to?(:hierarchy_class)
        model.hierarchy_class.arel_table
      elsif model.class.respond_to?(:hierarchy_class)
        model.class.hierarchy_class.arel_table
      else
        raise ArgumentError, "Cannot find hierarchy_class for #{model}"
      end
    end

    # Get hierarchy table using the model_class
    # This is for Support class methods
    def hierarchy_table
      @hierarchy_table ||= begin
        hierarchy_class_name = options[:hierarchy_class_name] || "#{model_class}Hierarchy"
        hierarchy_class_name.constantize.arel_table
      end
    end

    # Helper to create an Arel node for a table with an alias
    def aliased_table(table, alias_name)
      table.alias(alias_name)
    end

    # Build Arel queries for hierarchy operations
    def build_hierarchy_insert_query(hierarchy_table, node_id, parent_id)
      x = aliased_table(hierarchy_table, 'x')

      # Build the SELECT subquery - use SelectManager
      select_query = Arel::SelectManager.new(x)
      select_query.project(
        x[:ancestor_id],
        Arel.sql(quote(node_id)),
        x[:generations] + 1
      )
      select_query.where(x[:descendant_id].eq(parent_id))

      # Build the INSERT statement
      insert_manager = Arel::InsertManager.new
      insert_manager.into(hierarchy_table)
      insert_manager.columns << hierarchy_table[:ancestor_id]
      insert_manager.columns << hierarchy_table[:descendant_id]
      insert_manager.columns << hierarchy_table[:generations]
      insert_manager.select(select_query)

      insert_manager
    end

    def build_hierarchy_delete_query(hierarchy_table, id)
      # Build the innermost subquery
      inner_subquery_manager = Arel::SelectManager.new(hierarchy_table)
      inner_subquery_manager.project(hierarchy_table[:descendant_id])
      inner_subquery_manager.where(
        hierarchy_table[:ancestor_id].eq(id)
        .or(hierarchy_table[:descendant_id].eq(id))
      )
      inner_subquery = inner_subquery_manager.as('x')

      # Build the middle subquery with DISTINCT
      middle_subquery = Arel::SelectManager.new
      middle_subquery.from(inner_subquery)
      middle_subquery.project(inner_subquery[:descendant_id]).distinct

      # Build the DELETE statement
      delete_manager = Arel::DeleteManager.new
      delete_manager.from(hierarchy_table)
      delete_manager.where(hierarchy_table[:descendant_id].in(middle_subquery))

      delete_manager
    end
  end
end

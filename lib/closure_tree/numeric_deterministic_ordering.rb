# This module is only included if the order column is an integer.
module ClosureTree
  module DeterministicNumericOrdering
    extend ActiveSupport::Concern

    def self_and_descendants_preordered
      # TODO: raise NotImplementedError if sort_order is not numeric and not null?
      h = connection.select_one(<<-SQL)
        SELECT
          count(*) as total_descendants,
          max(generations) as max_depth
        FROM #{_ct.quoted_hierarchy_table_name}
        WHERE ancestor_id = #{_ct.quote(self.id)}
      SQL
      join_sql = <<-SQL
        JOIN #{_ct.quoted_hierarchy_table_name} anc_hier
          ON anc_hier.descendant_id = #{_ct.quoted_hierarchy_table_name}.descendant_id
        JOIN #{_ct.quoted_table_name} anc
          ON anc.id = anc_hier.ancestor_id
        JOIN #{_ct.quoted_hierarchy_table_name} depths
          ON depths.ancestor_id = #{_ct.quote(self.id)} AND depths.descendant_id = anc.id
      SQL
      node_score = "(1 + anc.#{_ct.quoted_order_column(false)}) * " +
        "power(#{h['total_descendants']}, #{h['max_depth'].to_i + 1} - depths.generations)"
      order_by = "sum(#{node_score})"
      self_and_descendants.joins(join_sql).group("#{_ct.quoted_table_name}.id").reorder(order_by)
    end

    module ClassMethods
      def roots_and_descendants_preordered
        h = connection.select_one(<<-SQL)
          SELECT
            count(*) as total_descendants,
            max(generations) as max_depth
          FROM #{_ct.quoted_hierarchy_table_name}
        SQL
        join_sql = <<-SQL
          JOIN #{_ct.quoted_hierarchy_table_name} anc_hier
            ON anc_hier.descendant_id = #{_ct.quoted_table_name}.id
          JOIN #{_ct.quoted_table_name} anc
            ON anc.id = anc_hier.ancestor_id
          JOIN (
            SELECT descendant_id, max(generations) AS max_depth
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY 1
          ) AS depths ON depths.descendant_id = anc.id
        SQL
        node_score = "(1 + anc.#{_ct.quoted_order_column(false)}) * " +
          "power(#{h['total_descendants']}, #{h['max_depth'].to_i + 1} - depths.max_depth)"
        order_by = "sum(#{node_score})"
        joins(join_sql).group("#{_ct.quoted_table_name}.id").reorder(order_by)
      end
    end

    def append_sibling(sibling_node, use_update_all = true)
      add_sibling(sibling_node, use_update_all, true)
    end

    def prepend_sibling(sibling_node, use_update_all = true)
      add_sibling(sibling_node, use_update_all, false)
    end

    def add_sibling(sibling_node, use_update_all = true, add_after = true)
      fail "can't add self as sibling" if self == sibling_node
      # issue 40: we need to lock the parent to prevent deadlocks on parallel sibling additions
      ct_with_advisory_lock do
        # issue 18: we need to set the order_value explicitly so subsequent orders will work.
        update_attribute(:order_value, 0) if self.order_value.nil?
        sibling_node.order_value = self.order_value.to_i + (add_after ? 1 : -1)
        # We need to incr the before_siblings to make room for sibling_node:
        if use_update_all
          col = _ct.quoted_order_column(false)
          # issue 21: we have to use the base class, so STI doesn't get in the way of only updating the child class instances:
          _ct.base_class.update_all(
            ["#{col} = #{col} #{add_after ? '+' : '-'} 1", "updated_at = now()"],
            ["#{_ct.quoted_parent_column_name} = ? AND #{col} #{add_after ? '>=' : '<='} ?",
              parent_id,
              sibling_node.order_value])
        else
          last_value = sibling_node.order_value.to_i
          (add_after ? siblings_after : siblings_before.reverse).each do |ea|
            last_value += (add_after ? 1 : -1)
            ea.order_value = last_value
            ea.save!
          end
        end
        sibling_node.parent = self.parent
        sibling_node.save!
        sibling_node.reload
      end
    end
  end
end

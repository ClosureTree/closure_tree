require 'active_support/concern'

# This module is only included if the order column is an integer.
module ClosureTree
  module NumericDeterministicOrdering
    extend ActiveSupport::Concern

    included do
      after_destroy :_ct_reorder_siblings
    end

    def _ct_reorder_prior_siblings_if_parent_changed
      if attribute_changed?(_ct.parent_column_name) && !@was_new_record
        was_parent_id = attribute_was(_ct.parent_column_name)
        _ct.reorder_with_parent_id(was_parent_id)
      end
    end

    def _ct_reorder_siblings(minimum_sort_order_value = nil)
      _ct.reorder_with_parent_id(_ct_parent_id, minimum_sort_order_value)
      reload unless destroyed?
    end

    def _ct_reorder_children(minimum_sort_order_value = nil)
      _ct.reorder_with_parent_id(_ct_id, minimum_sort_order_value)
    end

    def self_and_descendants_preordered
      # TODO: raise NotImplementedError if sort_order is not numeric and not null?
      h = _ct.connection.select_one(<<-SQL)
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
        h = _ct.connection.select_one(<<-SQL)
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

    def append_sibling(sibling_node)
      add_sibling(sibling_node, true)
    end

    def prepend_sibling(sibling_node)
      add_sibling(sibling_node, false)
    end

    def add_sibling(sibling, add_after = true)
      fail "can't add self as sibling" if self == sibling

      # Make sure self isn't dirty, because we're going to call reload:
      save

      _ct.with_advisory_lock do
        prior_sibling_parent = sibling.parent
        reorder_from_value = if prior_sibling_parent == self.parent
          [self.order_value, sibling.order_value].compact.min
        else
          self.order_value
        end

        sibling.order_value = self.order_value
        sibling.parent = self.parent
        sibling._ct_skip_sort_order_maintenance!
        sibling.save # may be a no-op

        _ct_reorder_siblings(reorder_from_value)

        # The sort order should be correct now except for self and sibling, which may need to flip:
        sibling_is_after = self.reload.sort_order < sibling.reload.sort_order
        if add_after != sibling_is_after
          # We need to flip the sort orders:
          self_so, sib_so = self.sort_order, sibling.sort_order
          update_order_value(sib_so)
          sibling.update_order_value(self_so)
        end

        if prior_sibling_parent != self.parent
          prior_sibling_parent.try(:_ct_reorder_children)
        end
        sibling
      end
    end
  end
end

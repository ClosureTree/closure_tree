require 'active_support/concern'

# This module is only included if the order column is an integer.
module ClosureTree
  module NumericDeterministicOrdering
    extend ActiveSupport::Concern

    included do
      after_destroy :_ct_reorder_siblings
    end

    def _ct_reorder_prior_siblings_if_parent_changed
      as_5_1 = ActiveSupport.version >= Gem::Version.new('5.1.0')
      change_method = as_5_1 ? :saved_change_to_attribute? : :attribute_changed?

      if public_send(change_method, _ct.parent_column_name) && !@was_new_record
        attribute_method = as_5_1 ? :attribute_before_last_save : :attribute_was

        was_parent_id = public_send(attribute_method, _ct.parent_column_name)
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
      join_sql = <<-SQL
        JOIN #{_ct.quoted_hierarchy_table_name} anc_hier
          ON anc_hier.descendant_id = #{_ct.quoted_hierarchy_table_name}.descendant_id
        JOIN #{_ct.quoted_table_name} anc
          ON anc.#{_ct.quoted_id_column_name} = anc_hier.ancestor_id
        JOIN #{_ct.quoted_hierarchy_table_name} depths
          ON depths.ancestor_id = #{_ct.quote(self.id)} AND depths.descendant_id = anc.#{_ct.quoted_id_column_name}
      SQL

      self_and_descendants
        .joins(join_sql)
        .group("#{_ct.quoted_table_name}.#{_ct.quoted_id_column_name}")
        .reorder(self.class._ct_sum_order_by(self))
    end

    module ClassMethods

      # If node is nil, order the whole tree.
      def _ct_sum_order_by(node = nil)
        stats_sql = <<-SQL.squish
          SELECT
            count(*) as total_descendants,
            max(generations) as max_depth
          FROM #{_ct.quoted_hierarchy_table_name}
        SQL
        stats_sql += " WHERE ancestor_id = #{_ct.quote(node.id)}" if node
        h = _ct.connection.select_one(stats_sql)

        depth_column = node ? 'depths.generations' : 'depths.max_depth'

        node_score = "(1 + anc.#{_ct.quoted_order_column(false)}) * " +
          "power(#{h['total_descendants']}, #{h['max_depth'].to_i + 1} - #{depth_column})"

        # We want the NULLs to be first in case we are not ordering roots and they have NULL order.
        Arel.sql("SUM(#{node_score}) IS NULL DESC, SUM(#{node_score})")
      end

      def roots_and_descendants_preordered
        if _ct.dont_order_roots
          raise ClosureTree::RootOrderingDisabledError.new("Root ordering is disabled on this model")
        end

        join_sql = <<-SQL.squish
          JOIN #{_ct.quoted_hierarchy_table_name} anc_hier
            ON anc_hier.descendant_id = #{_ct.quoted_table_name}.#{_ct.quoted_id_column_name}
          JOIN #{_ct.quoted_table_name} anc
            ON anc.#{_ct.quoted_id_column_name} = anc_hier.ancestor_id
          JOIN (
            SELECT descendant_id, max(generations) AS max_depth
            FROM #{_ct.quoted_hierarchy_table_name}
            GROUP BY descendant_id
          ) #{ _ct.t_alias_keyword } depths ON depths.descendant_id = anc.#{_ct.quoted_id_column_name}
        SQL
        joins(join_sql)
          .group("#{_ct.quoted_table_name}.#{_ct.quoted_id_column_name}")
          .reorder(_ct_sum_order_by)
      end
    end

    def append_child(child_node)
      add_child(child_node)
    end

    def prepend_child(child_node)
      child_node.order_value = -1
      child_node.parent = self
      child_node._ct_skip_sort_order_maintenance!
      if child_node.save
        _ct_reorder_children
        child_node.reload
      else
        child_node
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

      if _ct.dont_order_roots && parent.nil?
        raise ClosureTree::RootOrderingDisabledError.new("Root ordering is disabled on this model")
      end

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
        sibling_is_after = self.reload.order_value < sibling.reload.order_value
        if add_after != sibling_is_after
          # We need to flip the sort orders:
          self_ov, sib_ov = self.order_value, sibling.order_value
          update_order_value(sib_ov)
          sibling.update_order_value(self_ov)
        end

        if prior_sibling_parent != self.parent
          prior_sibling_parent.try(:_ct_reorder_children)
        end
        sibling
      end
    end
  end
end

# frozen_string_literal: true

require 'active_support/concern'

# This module is only included if the order column is an integer.
module ClosureTree
  module NumericDeterministicOrdering
    extend ActiveSupport::Concern

    included do
      after_destroy :_ct_reorder_siblings
    end

    def _ct_reorder_prior_siblings_if_parent_changed
      return unless saved_change_to_attribute?(_ct.parent_column_name) && !@was_new_record

      was_parent_id = attribute_before_last_save(_ct.parent_column_name)
      _ct.reorder_with_parent_id(was_parent_id)
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
      hierarchy_table = self.class.hierarchy_class.arel_table
      model_table = self.class.arel_table

      # Create aliased tables for the joins
      anc_hier = _ct.aliased_table(hierarchy_table, 'anc_hier')
      anc = _ct.aliased_table(model_table, 'anc')
      depths = _ct.aliased_table(hierarchy_table, 'depths')

      # Build the join conditions using Arel
      join_anc_hier = hierarchy_table
                      .join(anc_hier)
                      .on(anc_hier[:descendant_id].eq(hierarchy_table[:descendant_id]))

      join_anc = join_anc_hier
                 .join(anc)
                 .on(anc[self.class.primary_key].eq(anc_hier[:ancestor_id]))

      join_depths = join_anc
                    .join(depths)
                    .on(
                      depths[:ancestor_id].eq(id)
                      .and(depths[:descendant_id].eq(anc[self.class.primary_key]))
                    )

      self_and_descendants
        .joins(join_depths.join_sources)
        .group("#{_ct.quoted_table_name}.#{_ct.quoted_id_column_name}")
        .reorder(self.class._ct_sum_order_by(self))
    end

    class_methods do
      # If node is nil, order the whole tree.
      def _ct_sum_order_by(node = nil)
        # Build the stats query using Arel
        hierarchy_table = hierarchy_class.arel_table

        query = hierarchy_table
                .project(
                  Arel.star.count.as('total_descendants'),
                  hierarchy_table[:generations].maximum.as('max_depth')
                )

        query = query.where(hierarchy_table[:ancestor_id].eq(node.id)) if node

        h = _ct.connection.select_one(query.to_sql)

        depth_column = node ? 'depths.generations' : 'depths.max_depth'

        node_score = "(1 + anc.#{_ct.quoted_order_column(false)}) * " \
                     "power(#{h['total_descendants']}, #{h['max_depth'].to_i + 1} - #{depth_column})"

        # We want the NULLs to be first in case we are not ordering roots and they have NULL order.
        Arel.sql("SUM(#{node_score}) IS NULL DESC, SUM(#{node_score})")
      end

      def roots_and_descendants_preordered
        raise ClosureTree::RootOrderingDisabledError, 'Root ordering is disabled on this model' if _ct.dont_order_roots

        hierarchy_table = hierarchy_class.arel_table
        model_table = arel_table

        # Create aliased tables
        anc_hier = _ct.aliased_table(hierarchy_table, 'anc_hier')
        anc = _ct.aliased_table(model_table, 'anc')

        # Build the subquery for depths
        depths_subquery = hierarchy_table
                          .project(
                            hierarchy_table[:descendant_id],
                            hierarchy_table[:generations].maximum.as('max_depth')
                          )
                          .group(hierarchy_table[:descendant_id])
                          .as('depths')

        # Build the join conditions
        join_anc_hier = model_table
                        .join(anc_hier)
                        .on(anc_hier[:descendant_id].eq(model_table[primary_key]))

        join_anc = join_anc_hier
                   .join(anc)
                   .on(anc[primary_key].eq(anc_hier[:ancestor_id]))

        join_depths = join_anc
                      .join(depths_subquery)
                      .on(depths_subquery[:descendant_id].eq(anc[primary_key]))

        joins(join_depths.join_sources)
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
      raise "can't add self as sibling" if self == sibling

      if _ct.dont_order_roots && parent.nil?
        raise ClosureTree::RootOrderingDisabledError, 'Root ordering is disabled on this model'
      end

      # Make sure self isn't dirty, because we're going to call reload:
      save

      _ct.with_advisory_lock do
        prior_sibling_parent = sibling.parent
        reorder_from_value = if prior_sibling_parent == parent
                               [order_value, sibling.order_value].compact.min
                             else
                               order_value
                             end

        sibling.order_value = order_value
        sibling.parent = parent
        sibling._ct_skip_sort_order_maintenance!
        sibling.save # may be a no-op

        _ct_reorder_siblings(reorder_from_value)

        # The sort order should be correct now except for self and sibling, which may need to flip:
        sibling_is_after = reload.order_value < sibling.reload.order_value
        if add_after != sibling_is_after
          # We need to flip the sort orders:
          self_ov = order_value
          sib_ov = sibling.order_value
          update_order_value(sib_ov)
          sibling.update_order_value(self_ov)
        end

        prior_sibling_parent.try(:_ct_reorder_children) if prior_sibling_parent != parent
        sibling
      end
    end
  end
end

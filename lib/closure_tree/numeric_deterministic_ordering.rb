require 'active_support/concern'

# This module is only included if the order column is an integer.
module ClosureTree
  module NumericDeterministicOrdering
    extend ActiveSupport::Concern

    included do
      after_destroy :_ct_reorder_after_destroy
    end

    def _ct_reorder_after_destroy
      _ct_reorder_siblings
    end

    def _ct_reorder_prior_siblings_if_parent_changed
      if attribute_changed?(_ct.parent_column_name) && !@was_new_record
        was_parent_id = attribute_was(_ct.parent_column_name)
        _ct.reorder_with_parent_id(was_parent_id)
      else
        puts "#{self.to_s} didn't have parents change"
      end
    end

    def _ct_reorder_siblings(minimum_sort_order_value = nil, delta = 0)
      _ct.reorder_with_parent_id(_ct_parent_id, minimum_sort_order_value, delta)
      reload unless destroyed?
    end

    def _ct_reorder_children(minimum_sort_order_value = nil, delta = 0)
      _ct.reorder_with_parent_id(_ct_id, minimum_sort_order_value, delta)
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
      _ct.with_advisory_lock do
        if self.order_value.nil?
          # ergh, we don't know where we stand within the siblings, so establish that first:
          _ct_reorder_siblings
          reload # < because self.order_value changed
        end
        prior_sibling_parent = sibling.parent
        if prior_sibling_parent == self.parent
          # We have to adjust the prior siblings by moving sibling out of the way:
          sibling._ct_update_column(_ct.parent_column_sym, nil)
          if sibling.order_value && sibling.order_value < self.order_value
            _ct_reorder_siblings(sibling.order_value, 0)
            reload # < because self.order_value changed
          end
        end
        _ct_move_new_sibling(sibling, add_after)
        if prior_sibling_parent && prior_sibling_parent != self.parent
          prior_sibling_parent._ct_reorder_children
        end
        sibling
      end
    end

    def _ct_move_new_sibling(sibling, add_after)
      _ct_reorder_siblings(self.order_value + 1, 1)
      if add_after
        sibling.order_value = self.order_value + 1
      else
        sibling.order_value = self.order_value
        self.order_value += 1
        self.save!
      end
      parent.add_child(sibling) # <- this causes sibling to be saved.
    end
  end
end

require 'active_support/concern'

# This module is only included if the order column is an integer.
module ClosureTree
  module NumericDeterministicOrdering
    extend ActiveSupport::Concern

    included do
      after_destroy :_ct_reorder_siblings
      driver = "::ClosureTree::NumericDeterministicOrdering::#{connection.class.to_s.demodulize}"
      include driver.constantize
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

    def add_sibling(sibling_node, add_after = true)
      fail "can't add self as sibling" if self == sibling_node
      _ct.with_advisory_lock do
        if self.order_value.nil? || siblings_before.without(sibling_node).empty?
          update_attribute(:order_value, 0)
        end
        sibling_node.parent = self.parent
        starting_order_value = self.order_value.to_i
        to_reorder = siblings_after.without(sibling_node).to_a
        if add_after
          to_reorder.unshift(sibling_node)
        else
          to_reorder.unshift(self)
          sibling_node.update_attribute(:order_value, starting_order_value)
        end

        to_reorder.each_with_index do |ea, idx|
          ea.update_attribute(:order_value, starting_order_value + idx + 1)
        end
        sibling_node.reload # because the parent may have changed.
      end
    end

    module Mysql2Adapter
      def _ct_reorder_siblings
        transaction do
          _ct.connection.execute "SET @i = -1"
          _ct.connection.execute <<-SQL
            UPDATE #{_ct.quoted_table_name}
              SET #{_ct.quoted_order_column(false)} = (@i := @i + 1)
            WHERE #{_ct.quoted_parent_column_name} = #{_ct_quoted_parent_id}
            ORDER BY #{_ct.options[:order]}
          SQL
        end
      end
    end

    module PostgreSQLAdapter
      def _ct_reorder_siblings
        transaction do
          _ct.connection.execute <<-SQL
            UPDATE #{_ct.quoted_table_name}
              SET #{_ct.quoted_order_column(false)} = row_number()
            WHERE #{_ct.quoted_parent_column_name} = #{_ct_quoted_parent_id}
            ORDER BY #{_ct.options[:order]}
          SQL
        end
      end
    end

    module SQLite3Adapter
      def _ct_reorder_siblings
        transaction do
          self_and_siblings.each_with_index do |ea, idx|
            ea.update_attribute(_ct.order_column_sym, idx)
          end
        end
      end
    end
  end
end

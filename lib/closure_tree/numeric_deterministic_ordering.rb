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
        prior_sibling_parent = sibling_node.parent
        if self.order_value.nil? || siblings_before.without(sibling_node).empty?
          update_attribute(:order_value, 0)
        end
        _ct_reorder_siblings(order_value + 1, 1)
        if add_after
          sibling_node.order_value = self.order_value + 1
        else
          sibling_node.order_value = self.order_value
          self.order_value += 1
          self.save!
        end
        parent.add_child(sibling_node) # <- this causes sibling_node to be saved.
        if prior_sibling_parent
          first_child = prior_sibling_parent.children.first
          first_child._ct_reorder_siblings if first_child
        end
        sibling_node
      end
    end

    module Mysql2Adapter
      def _ct_reorder_siblings(minimum_sort_order_value = 0, delta = 0)
        transaction do
          _ct.connection.execute "SET @i = #{minimum_sort_order_value} - 1"
          _ct.connection.execute <<-SQL
            UPDATE #{_ct.quoted_table_name}
              SET #{_ct.quoted_order_column} = (@i := @i + 1) + #{delta}
            WHERE #{_ct.quoted_parent_column_name} = #{_ct_quoted_parent_id}
              AND #{_ct.quoted_order_column} >= #{minimum_sort_order_value}
            ORDER BY #{_ct.options[:order]}
          SQL
        end
      end
    end

    module PostgreSQLAdapter
      def _ct_reorder_siblings(minimum_sort_order_value = 0, delta = 0)
        transaction do
          _ct.connection.execute <<-SQL
            UPDATE #{_ct.quoted_table_name}
              SET #{_ct.quoted_order_column(false)} = row_number() + #{minimum_sort_order_value} + #{delta}
            WHERE #{_ct.quoted_parent_column_name} = #{_ct_quoted_parent_id}
              AND #{_ct.quoted_order_column} >= #{minimum_sort_order_value}
            ORDER BY #{_ct.options[:order]}
          SQL
        end
      end
    end

    module SQLite3Adapter
      def _ct_reorder_siblings(minimum_sort_order_value = 0, delta = 0)
        transaction do
          self_and_siblings.
            where("#{_ct.quoted_order_column} >= #{minimum_sort_order_value}").
            each_with_index do |ea, idx|
            ea.update_attribute(_ct.order_column_sym, idx + minimum_sort_order_value + delta)
          end
        end
      end
    end
  end
end

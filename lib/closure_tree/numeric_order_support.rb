module ClosureTree
  module NumericOrderSupport
    module MysqlAdapter
      module_function def reorder_with_parent_id(ct, parent_id, minimum_sort_order_value = nil)
        return if parent_id.nil? && ct.dont_order_roots

        min_where = if minimum_sort_order_value
          "AND #{ct.quoted_order_column} >= #{minimum_sort_order_value}"
        else
          ""
        end
        ct.connection.execute 'SET @i = 0'
        ct.connection.execute <<-SQL.squish
          UPDATE #{ct.quoted_table_name}
            SET #{ct.quoted_order_column} = (@i := @i + 1) + #{minimum_sort_order_value.to_i - 1}
          WHERE #{ct.where_eq(ct.parent_column_name, parent_id)} #{min_where}
          ORDER BY #{ct.nulls_last_order_by}
        SQL
      end
    end

    module PostgreSQLAdapter
      module_function def reorder_with_parent_id(ct, parent_id, minimum_sort_order_value = nil)
        return if parent_id.nil? && ct.dont_order_roots
        min_where = if minimum_sort_order_value
          "AND #{ct.quoted_order_column} >= #{minimum_sort_order_value}"
        else
          ""
        end
        ct.connection.execute <<-SQL.squish
          UPDATE #{ct.quoted_table_name}
          SET #{ct.quoted_order_column(false)} = t.seq + #{minimum_sort_order_value.to_i - 1}
          FROM (
            SELECT #{ct.quoted_id_column_name} AS id, row_number() OVER(ORDER BY #{ct.order_by}) AS seq
            FROM #{ct.quoted_table_name}
            WHERE #{ct.where_eq(ct.parent_column_name, parent_id)} #{min_where}
          ) AS t
          WHERE #{ct.quoted_table_name}.#{ct.quoted_id_column_name} = t.id and
                #{ct.quoted_table_name}.#{ct.quoted_order_column(false)} is distinct from t.seq + #{minimum_sort_order_value.to_i - 1}
        SQL
      end

      def rows_updated(result)
        result.cmd_status.sub(/\AUPDATE /, '').to_i
      end
    end

    module GenericAdapter
      module_function def reorder_with_parent_id(ct, parent_id, minimum_sort_order_value = nil)
        return if parent_id.nil? && ct.dont_order_roots
        binding.irb
        scope = ct.
          where(ct.parent_column_sym => parent_id).
          order(ct.nulls_last_order_by)
        if minimum_sort_order_value
          scope = scope.where("#{ct.quoted_order_column} >= #{minimum_sort_order_value}")
        end
        scope.each_with_index do |ea, idx|
          ea.update_order_value(idx + minimum_sort_order_value.to_i)
        end
      end
    end


    module_function def adapter_for_connection(ct, parent_id, minimum_sort_order_value = nil)
      das = WithAdvisoryLock::DatabaseAdapterSupport.new(ct.connection)
      if das.postgresql?
        PostgreSQLAdapter.reorder_with_parent_id(ct, parent_id, minimum_sort_order_value = nil)
      elsif das.mysql?
        MysqlAdapter.reorder_with_parent_id(ct, parent_id, minimum_sort_order_value = nil)
      else
        GenericAdapter.reorder_with_parent_id(ct, parent_id, minimum_sort_order_value = nil)
      end
    end
  end
end

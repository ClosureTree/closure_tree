module ClosureTree
  module NumericOrderSupport

    def self.adapter_for_connection(connection)
      das = WithAdvisoryLock::DatabaseAdapterSupport.new(connection)
      if das.postgresql?
        ::ClosureTree::NumericOrderSupport::PostgreSQLAdapter
      elsif das.mysql?
        ::ClosureTree::NumericOrderSupport::MysqlAdapter
      else
        ::ClosureTree::NumericOrderSupport::GenericAdapter
      end
    end

    module MysqlAdapter
      def reorder_with_parent_id(parent_id, minimum_sort_order_value = nil, delta = 0)
        min_where = if minimum_sort_order_value
          "AND #{quoted_order_column} >= #{minimum_sort_order_value}"
        else
          ""
        end
        connection.execute "SET @i = 0"
        connection.execute <<-SQL
          UPDATE #{quoted_table_name}
            SET #{quoted_order_column} = (@i := @i + 1) + #{minimum_sort_order_value.to_i + delta - 1}
          WHERE #{quoted_parent_column_name} #{parent_id.nil? ? "IS" : "="} #{quoted_value(parent_id)} #{min_where}
          ORDER BY #{order_by}
        SQL
      end
    end

    module PostgreSQLAdapter
      def reorder_with_parent_id(parent_id, minimum_sort_order_value = nil, delta = 0)
        min_where = if minimum_sort_order_value
          "AND #{quoted_order_column} >= #{minimum_sort_order_value}"
        else
          ""
        end
        connection.execute <<-SQL
          UPDATE #{quoted_table_name}
          SET #{quoted_order_column(false)} = t.seq + #{minimum_sort_order_value.to_i + delta - 1}
          FROM (
            SELECT #{quoted_id_column_name} AS id, row_number() OVER(ORDER BY #{order_by}) AS seq
            FROM #{quoted_table_name}
            WHERE #{quoted_parent_column_name} #{parent_id.nil? ? "IS" : "="} #{quoted_value(parent_id)} #{min_where}) AS t
          WHERE #{quoted_table_name}.#{quoted_id_column_name} = t.id
        SQL
      end
    end

    module GenericAdapter
      def reorder_with_parent_id(parent_id, minimum_sort_order_value = nil, delta = 0)
        scope = model_class.where("#{parent_column_sym} #{parent_id.nil? ? 'IS' : '='} #{parent_id.nil? ? 'NULL' : parent_id}")
        if minimum_sort_order_value
          scope = scope.where("#{quoted_order_column} >= #{minimum_sort_order_value}")
        end
        scope.each_with_index do |ea, idx|
          ea.update_attribute(order_column_sym, idx + minimum_sort_order_value.to_i + delta)
        end
      end
    end
  end
end

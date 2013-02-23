module ClosureTree
  module DeterministicOrdering
    def order_column
      o = order_option
      o.split(' ', 2).first if o
    end

    def require_order_column
      raise ":order value, '#{order_option}', isn't a column" if order_column.nil?
    end

    def order_column_sym
      require_order_column
      order_column.to_sym
    end

    def order_value
      read_attribute(order_column_sym)
    end

    def order_value=(new_order_value)
      write_attribute(order_column_sym, new_order_value)
    end

    def quoted_order_column(include_table_name = true)
      require_order_column
      prefix = include_table_name ? "#{quoted_table_name}." : ""
      "#{prefix}#{connection.quote_column_name(order_column)}"
    end

    def siblings_before
      siblings.where(["#{quoted_order_column} < ?", order_value])
    end

    def siblings_after
      siblings.where(["#{quoted_order_column} > ?", order_value])
    end
  end
end
module ClosureTree
  module DeterministicOrdering
    def order_value
      read_attribute(_ct.order_column_sym)
    end

    def update_order_value(order_value)
      update_column(_ct.order_column_sym, order_value)
    end

    def order_value=(new_order_value)
      write_attribute(_ct.order_column_sym, new_order_value)
    end

    def siblings_before
      siblings.where(["#{_ct.quoted_order_column} < ?", order_value])
    end

    def siblings_after
      siblings.where(["#{_ct.quoted_order_column} > ?", order_value])
    end
  end
end

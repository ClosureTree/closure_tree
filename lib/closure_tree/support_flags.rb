# frozen_string_literal: true

module ClosureTree
  module SupportFlags
    def order_option?
      order_by.present?
    end

    def order_is_numeric?
      options[:numeric_order]
    end

    def subclass?
      model_class != model_class.base_class
    end

    def has_inheritance_column?(hash = columns_hash)
      hash.with_indifferent_access.include?(model_class.inheritance_column)
    end

    def has_name?
      model_class.new.attributes.include? options[:name_column]
    end
  end
end

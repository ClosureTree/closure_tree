module ClosureTree
  module SupportFlags

    def use_attr_accessible?
      defined?(ActiveModel::MassAssignmentSecurity) &&
        model_class.respond_to?(:accessible_attributes) &&
        ! model_class.accessible_attributes.empty?
    end

    def include_forbidden_attributes_protection?
      defined?(ActiveModel::ForbiddenAttributesProtection) &&
        model_class.ancestors.include?(ActiveModel::ForbiddenAttributesProtection)
    end

    def order_option?
      order_by.present?
    end

    def order_is_numeric?
      # The table might not exist yet (in the case of ActiveRecord::Observer use, see issue 32)
      return false if !order_option? || !model_class.table_exists?
      c = model_class.columns_hash[order_column]
      c && c.type == :integer
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

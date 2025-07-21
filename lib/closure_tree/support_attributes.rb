# frozen_string_literal: true

require 'forwardable'
require 'zlib'

module ClosureTree
  module SupportAttributes
    extend Forwardable
    def_delegators :model_class, :connection, :transaction, :table_name, :base_class, :inheritance_column, :column_names

    def advisory_lock_name
      # Allow customization via options or instance method
      if options[:advisory_lock_name]
        case options[:advisory_lock_name]
        when Proc
          # Allow dynamic generation via proc
          options[:advisory_lock_name].call(base_class)
        when Symbol
          # Allow delegation to a model method
          if model_class.respond_to?(options[:advisory_lock_name])
            model_class.send(options[:advisory_lock_name])
          else
            raise ArgumentError, "Model #{model_class} does not respond to #{options[:advisory_lock_name]}"
          end
        else
          # Use static string value
          options[:advisory_lock_name].to_s
        end
      else
        # Default: Use CRC32 for a shorter, consistent hash
        # This gives us 8 hex characters which is plenty for uniqueness
        # and leaves room for prefixes
        "ct_#{Zlib.crc32(base_class.name.to_s).to_s(16)}"
      end
    end

    def quoted_table_name
      connection.quote_table_name(table_name)
    end

    def quoted_value(value)
      value.is_a?(Numeric) ? value : quote(value)
    end

    def hierarchy_class_name
      options[:hierarchy_class_name] || "#{model_class}Hierarchy"
    end

    def primary_key_column
      model_class.columns.detect { |ea| ea.name == model_class.primary_key }
    end

    def primary_key_type
      primary_key_column.type
    end

    def parent_column_name
      options[:parent_column_name]
    end

    def parent_column_sym
      parent_column_name.to_sym
    end

    def name_column
      options[:name_column]
    end

    def name_sym
      name_column.to_sym
    end

    # Returns the constant name of the hierarchy_class
    #
    # @return [String] the constant name
    #
    # @example
    #   Namespace::Model.hierarchy_class_name # => "Namespace::ModelHierarchy"
    #   Namespace::Model.short_hierarchy_class_name # => "ModelHierarchy"
    def short_hierarchy_class_name
      hierarchy_class_name.split('::').last
    end

    def quoted_hierarchy_table_name
      connection.quote_table_name hierarchy_table_name
    end

    def quoted_id_column_name
      connection.quote_column_name model_class.primary_key
    end

    def quoted_parent_column_name
      connection.quote_column_name parent_column_name
    end

    def quoted_name_column
      connection.quote_column_name name_column
    end

    def order_by
      options[:order]
    end

    def dont_order_roots
      options[:dont_order_roots] || false
    end

    def nulls_last_order_by
      Arel.sql "-#{quoted_order_column} #{order_by_order(true)}"
    end

    def order_by_order(reverse = false)
      desc = !(order_by.to_s =~ /DESC\z/).nil?
      desc = !desc if reverse
      desc ? 'DESC' : 'ASC'
    end

    def order_column
      o = order_by
      if o.nil?
        nil
      elsif o.is_a?(String)
        o.split(' ', 2).first
      else
        o.to_s
      end
    end

    def require_order_column
      raise ":order value, '#{options[:order]}', isn't a column" if order_column.nil?
    end

    def order_column_sym
      require_order_column
      order_column.to_sym
    end

    def quoted_order_column(include_table_name = true)
      require_order_column
      prefix = include_table_name ? "#{quoted_table_name}." : ''
      "#{prefix}#{connection.quote_column_name(order_column)}"
    end

    # table_name alias keyword , like "AS". When used on table name alias, Oracle Database don't support used 'AS'
    def t_alias_keyword
      ActiveRecord::Base.connection.adapter_name.to_sym == :OracleEnhanced ? '' : 'AS'
    end
  end
end

# frozen_string_literal: true

# This class and mixins are an effort to reduce the namespace pollution to models that act_as_tree.
module ClosureTree
  class Support
    include ClosureTree::SupportFlags
    include ClosureTree::SupportAttributes
    include ClosureTree::ActiveRecordSupport
    include ClosureTree::HashTreeSupport
    include ClosureTree::ArelHelpers

    attr_reader :model_class, :options

    def initialize(model_class, options)
      @model_class = model_class

      @options = {
        parent_column_name: 'parent_id',
        dependent: :nullify, # or :destroy or :delete_all -- see the README
        name_column: 'name',
        with_advisory_lock: true, # This will be overridden by adapter support
        numeric_order: false
      }.merge(options)
      raise ArgumentError, "name_column can't be 'path'" if options[:name_column] == 'path'

      return unless order_is_numeric?

      extend NumericOrderSupport.adapter_for_connection(connection)
    end

    def hierarchy_class_for_model
      parent_class = model_class.module_parent
      hierarchy_class = parent_class.const_set(short_hierarchy_class_name, Class.new(model_class.superclass))
      model_class_name = model_class.to_s
      hierarchy_class.class_eval do
        belongs_to :ancestor, class_name: model_class_name
        belongs_to :descendant, class_name: model_class_name
        def ==(other)
          self.class == other.class && ancestor_id == other.ancestor_id && descendant_id == other.descendant_id
        end
        alias :eql? :==
        def hash
          (ancestor_id.hash << 31) ^ descendant_id.hash
        end
      end
      hierarchy_class.table_name = hierarchy_table_name
      hierarchy_class
    end

    def hierarchy_table_name
      # We need to use the table_name, not something like ct_class.to_s.demodulize + "_hierarchies",
      # because they may have overridden the table name, which is what we want to be consistent with
      # in order for the schema to make sense.
      tablename = options[:hierarchy_table_name] ||
                  "#{remove_prefix_and_suffix(table_name, model_class).singularize}_hierarchies"

      [model_class.table_name_prefix, tablename, model_class.table_name_suffix].join
    end

    def with_order_option(opts)
      opts[:order] = [opts[:order], order_by].compact.join(',') if order_option?
      opts
    end

    def scope_with_order(scope, additional_order_by = nil)
      if order_option?
        scope.order(*[additional_order_by, order_by].compact)
      else
        additional_order_by ? scope.order(additional_order_by) : scope
      end
    end

    # lambda-ize the order, but don't apply the default order_option
    def has_many_order_without_option(order_by_opt)
      [-> { order(order_by_opt.call) }]
    end

    def has_many_order_with_option(order_by_opt = nil)
      order_options = [order_by_opt, order_by].compact
      [lambda {
        order_options = order_options.map { |o| o.is_a?(Proc) ? o.call : o }
        order(order_options)
      }]
    end

    def ids_from(scope)
      scope.pluck(model_class.primary_key)
    end

    def where_eq(column_name, value)
      if value.nil?
        "#{connection.quote_column_name(column_name)} IS NULL"
      else
        "#{connection.quote_column_name(column_name)} = #{quoted_value(value)}"
      end
    end

    def with_advisory_lock(&block)
      if options[:with_advisory_lock] && connection.supports_advisory_locks? && model_class.respond_to?(:with_advisory_lock)
        model_class.with_advisory_lock(advisory_lock_name) do
          transaction(&block)
        end
      else
        yield
      end
    end

    def build_ancestry_attr_path(path, attributes)
      path = path.is_a?(Array) ? path.dup : [path]
      unless path.first.is_a?(Hash)
        if subclass? && has_inheritance_column?
          attributes = attributes.with_indifferent_access
          attributes[inheritance_column] ||= sti_name
        end
        path = path.map { |ea| attributes.merge(name_column => ea) }
      end
      path
    end

    def scoped_attributes(scope, attributes, target_table = model_class.table_name)
      table_prefixed_attributes = attributes.transform_keys do |column_name|
        "#{target_table}.#{column_name}"
      end
      scope.where(table_prefixed_attributes)
    end

    def max_join_tables
      # MySQL doesn't support more than 61 joined tables (!!):
      50
    end

    def find_by_large_path(path, attributes = {}, parent_id = nil)
      next_parent_id = parent_id
      child = nil
      path.in_groups(max_join_tables, false).each do |subpath|
        child = model_class.find_by_path(subpath, attributes, next_parent_id)
        return nil if child.nil?

        next_parent_id = child._ct_id
      end
      child
    end

    def creator_class(model_class, sti_class)
      if sti_class.present?
        base_class.send(:find_sti_class, sti_class)
      else
        model_class
      end
    end

    def create(model_class, attributes)
      creator_class(model_class, attributes.with_indifferent_access[inheritance_column]).new(attributes)
    end

    def create!(model_class, attributes)
      create(model_class, attributes).tap(&:save!)
    end
  end
end

require 'closure_tree/support_flags'
require 'closure_tree/support_attributes'
require 'closure_tree/numeric_order_support'

module ClosureTree
  class Support
    include ClosureTree::SupportFlags
    include ClosureTree::SupportAttributes

    attr_reader :model_class
    attr_reader :options

    def initialize(model_class, options)
      @model_class = model_class
      @options = {
        :base_class => model_class,
        :parent_column_name => 'parent_id',
        :dependent => :nullify, # or :destroy or :delete_all -- see the README
        :name_column => 'name',
        :with_advisory_lock => true
      }.merge(options)
      raise IllegalArgumentException, "name_column can't be 'path'" if options[:name_column] == 'path'
      if order_is_numeric?
        extend NumericOrderSupport.adapter_for_connection(connection)
      end
    end

    def hierarchy_class_for_model
      hierarchy_class = model_class.parent.const_set(short_hierarchy_class_name, Class.new(ActiveRecord::Base))
      use_attr_accessible = use_attr_accessible?
      include_forbidden_attributes_protection = include_forbidden_attributes_protection?
      hierarchy_class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        include ActiveModel::ForbiddenAttributesProtection if include_forbidden_attributes_protection
        belongs_to :ancestor, :class_name => "#{model_class}"
        belongs_to :descendant, :class_name => "#{model_class}"
        attr_accessible :ancestor, :descendant, :generations if use_attr_accessible
        def ==(other)
          self.class == other.class && ancestor_id == other.ancestor_id && descendant_id == other.descendant_id
        end
        alias :eql? :==
        def hash
          ancestor_id.hash << 31 ^ descendant_id.hash
        end
      RUBY
      hierarchy_class.table_name = hierarchy_table_name
      hierarchy_class
    end

    def hierarchy_table_name
      # We need to use the table_name, not something like ct_class.to_s.demodulize + "_hierarchies",
      # because they may have overridden the table name, which is what we want to be consistent with
      # in order for the schema to make sense.
      tablename = options[:hierarchy_table_name] ||
        remove_prefix_and_suffix(table_name).singularize + "_hierarchies"

      ActiveRecord::Base.table_name_prefix + tablename + ActiveRecord::Base.table_name_suffix
    end

    def quote(field)
      connection.quote(field)
    end

    def with_order_option(opts)
      if order_option?
        opts[:order] = [opts[:order], order_by].compact.join(",")
      end
      opts
    end

    def scope_with_order(scope, additional_order_by = nil)
      if order_option?
        scope.order(*([additional_order_by, order_by].compact))
      else
        additional_order_by ? scope.order(additional_order_by) : scope
      end
    end

    # lambda-ize the order, but don't apply the default order_option
    def has_many_without_order_option(opts)
      if ActiveRecord::VERSION::MAJOR > 3
        [lambda { order(opts[:order]) }, opts.except(:order)]
      else
        [opts]
      end
    end

    def has_many_with_order_option(opts)
      if ActiveRecord::VERSION::MAJOR > 3
        order_options = [opts[:order], order_by].compact
        [lambda { order(order_options) }, opts.except(:order)]
      else
        [with_order_option(opts)]
      end
    end

    def remove_prefix_and_suffix(table_name)
      pre, suff = ActiveRecord::Base.table_name_prefix, ActiveRecord::Base.table_name_suffix
      if table_name.start_with?(pre) && table_name.end_with?(suff)
        table_name[pre.size..-(suff.size + 1)]
      else
        table_name
      end
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
      if options[:with_advisory_lock]
        model_class.with_advisory_lock("closure_tree") do
          transaction { yield }
        end
      else
        yield
      end
    end
  end
end

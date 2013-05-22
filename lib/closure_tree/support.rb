module ClosureTree
  class Support

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
    end

    def connection
      model_class.connection
    end

    def use_attr_accessible?
      defined?(ActiveModel::ForbiddenAttributesProtection) && !defined?(ActiveModel::DeprecatedMassAssignmentSecurity)
    end

    def hierarchy_class_for_model
      hierarchy_class = model_class.parent.const_set(short_hierarchy_class_name, Class.new(ActiveRecord::Base))
      use_attr_accessible = use_attr_accessible?
      hierarchy_class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
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

    def parent_column_name
      options[:parent_column_name]
    end

    def parent_column_sym
      parent_column_name.to_sym
    end

    def has_name?
      model_class.new.attributes.include? options[:name_column]
    end

    def name_column
      options[:name_column]
    end

    def name_sym
      name_column.to_sym
    end

    def hierarchy_table_name
      # We need to use the table_name, not something like ct_class.to_s.demodulize + "_hierarchies",
      # because they may have overridden the table name, which is what we want to be consistent with
      # in order for the schema to make sense.
      tablename = options[:hierarchy_table_name] ||
        remove_prefix_and_suffix(table_name).singularize + "_hierarchies"

      ActiveRecord::Base.table_name_prefix + tablename + ActiveRecord::Base.table_name_suffix
    end

    def hierarchy_class_name
      options[:hierarchy_class_name] || model_class.to_s + "Hierarchy"
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

    def quoted_parent_column_name
      connection.quote_column_name parent_column_name
    end

    def quoted_name_column
      connection.quote_column_name name_column
    end

    def quote(field)
      connection.quote(field)
    end

    def order_option?
      !options[:order].nil?
    end

    def order_option
      options[:order].to_s
    end

    def with_order_option(options)
      if order_option?
        options[:order] = [options[:order], order_option].compact.join(",")
      end
      options
    end

    def scope_with_order(scope, additional_order_by = nil)
      order_option? ? scope.order(*([additional_order_by, order_option].compact)) : scope
    end

    # lambda-ize the order, but don't apply the default order_option
    def has_many_without_order_option(opts)
      if ActiveRecord::VERSION::MAJOR == 4
        [lambda { order(opts[:order]) }, opts.except(:order)]
      else
        [opts]
      end
    end

    def has_many_with_order_option(opts)
      if ActiveRecord::VERSION::MAJOR == 4
        order_options = [options[:order], opts[:order]].compact
        [lambda { order(order_options) }, opts.except(:order)]
      else
        [with_order_option(opts)]
      end
    end

    def order_is_numeric?
      # The table might not exist yet (in the case of ActiveRecord::Observer use, see issue 32)
      return false if !order_option? || !model_class.table_exists?
      c = model_class.columns_hash[order_option]
      c && c.type == :integer
    end

    def order_column
      order_option.split(' ', 2).first if order_option?
    end

    def require_order_column
      raise ":order value, '#{order_option}', isn't a column" if order_column.nil?
    end

    def order_column_sym
      require_order_column
      order_column.to_sym
    end

    def quoted_order_column(include_table_name = true)
      require_order_column
      prefix = include_table_name ? "#{quoted_table_name}." : ""
      "#{prefix}#{connection.quote_column_name(order_column)}"
    end

    # This is the "topmost" class. This will only potentially not be ct_class if you are using STI.
    def base_class
      options[:base_class]
    end

    def subclass?
      model_class != model_class.base_class
    end

    def attribute_names
      @attribute_names ||= model_class.new.attributes.keys - model_class.protected_attributes.to_a
    end

    def has_type?
      attribute_names.include? 'type'
    end

    def table_name
      model_class.table_name
    end

    def quoted_table_name
      connection.quote_table_name table_name
    end

    def remove_prefix_and_suffix(table_name)
      prefix = Regexp.escape(ActiveRecord::Base.table_name_prefix)
      suffix = Regexp.escape(ActiveRecord::Base.table_name_suffix)
      table_name.gsub(/^#{prefix}(.+)#{suffix}$/, "\\1")
    end

    def ids_from(scope)
      if scope.respond_to? :pluck
        scope.pluck(:id)
      else
        scope.select(:id).collect(&:id)
      end
    end
  end
end

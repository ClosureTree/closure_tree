require 'closure_tree/columns'
require 'closure_tree/deterministic_ordering'
require 'closure_tree/model'
require 'closure_tree/numeric_deterministic_ordering'
require 'closure_tree/with_advisory_lock'

module ClosureTree
  module ActsAsTree
    def acts_as_tree(options = {})

      class_attribute :closure_tree_options

      self.closure_tree_options = {
        :ct_base_class => self,
        :parent_column_name => 'parent_id',
        :dependent => :nullify, # or :destroy or :delete_all -- see the README
        :name_column => 'name',
        :with_advisory_lock => true
      }.merge(options)

      raise IllegalArgumentException, "name_column can't be 'path'" if closure_tree_options[:name_column] == 'path'

      include ClosureTree::Columns
      extend ClosureTree::Columns

      include ClosureTree::WithAdvisoryLock
      extend ClosureTree::WithAdvisoryLock

      # Auto-inject the hierarchy table
      # See https://github.com/patshaughnessy/class_factory/blob/master/lib/class_factory/class_factory.rb
      class_attribute :hierarchy_class
      self.hierarchy_class = Object.const_set hierarchy_class_name, Class.new(ActiveRecord::Base)

      self.hierarchy_class.class_eval <<-RUBY
        belongs_to :ancestor, :class_name => "#{ct_class.to_s}"
        belongs_to :descendant, :class_name => "#{ct_class.to_s}"
        attr_accessible :ancestor, :descendant, :generations
        def ==(comparison_object)
          comparison_object.instance_of?(self.class) &&
          self.attributes == comparison_object.attributes
        end
        alias :eql? :==
        def hash
          attributes.hash
        end
      RUBY

      self.hierarchy_class.table_name = hierarchy_table_name

      include ClosureTree::Model
      unless order_option.nil?
        include ClosureTree::DeterministicOrdering
        include ClosureTree::DeterministicNumericOrdering if order_is_numeric
      end
    end
  end
end
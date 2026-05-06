# frozen_string_literal: true

require 'test_helper'

# Test for advisory lock name customization
class AdvisoryLockTest < ActiveSupport::TestCase
  def setup
    Tag.delete_all
    Tag.hierarchy_class.delete_all
  end

  def test_default_advisory_lock_name
    tag = Tag.new
    expected_name = "ct_#{Zlib.crc32(Tag.base_class.name.to_s).to_s(16)}"
    assert_equal expected_name, tag._ct.advisory_lock_name
  end

  def test_static_string_advisory_lock_name
    with_temporary_model do
      has_closure_tree advisory_lock_name: 'custom_lock_name'
    end

    instance = @model_class.new
    assert_equal 'custom_lock_name', instance._ct.advisory_lock_name
  end

  def test_proc_advisory_lock_name
    with_temporary_model do
      has_closure_tree advisory_lock_name: ->(model) { "lock_for_#{model.name.underscore}" }
    end

    instance = @model_class.new
    assert_equal "lock_for_#{@model_class.name.underscore}", instance._ct.advisory_lock_name
  end

  def test_proc_advisory_lock_name_with_instance_arity
    with_temporary_model do
      has_closure_tree advisory_lock_name: ->(klass, instance) {
        tenant = instance&.name
        tenant ? "#{klass.name.underscore}_#{tenant}" : "#{klass.name.underscore}_global"
      }
    end

    instance = @model_class.new
    instance.name = "acme"

    assert_equal "#{@model_class.name.underscore}_global", @model_class._ct.advisory_lock_name(nil)
    assert_equal "#{@model_class.name.underscore}_acme", @model_class._ct.advisory_lock_name(instance)
  end

  def test_proc_arity_1_backward_compat
    with_temporary_model do
      has_closure_tree advisory_lock_name: ->(model) { "compat_#{model.name}" }
    end

    instance = @model_class.new
    assert_equal "compat_#{@model_class.name}", @model_class._ct.advisory_lock_name(instance)
    assert_equal "compat_#{@model_class.name}", @model_class._ct.advisory_lock_name(nil)
  end

  def test_different_instances_produce_different_lock_names
    with_temporary_model do
      has_closure_tree advisory_lock_name: ->(klass, instance) {
        tenant = instance&.name
        tenant ? "ct_#{klass.name}_#{tenant}" : "ct_#{klass.name}"
      }
    end

    instance_a = @model_class.new.tap { |i| i.name = "tenant_a" }
    instance_b = @model_class.new.tap { |i| i.name = "tenant_b" }

    lock_a = @model_class._ct.advisory_lock_name(instance_a)
    lock_b = @model_class._ct.advisory_lock_name(instance_b)
    lock_global = @model_class._ct.advisory_lock_name(nil)

    assert_not_equal lock_a, lock_b, "Different tenants must not share a lock"
    assert_not_equal lock_a, lock_global, "Instance lock must differ from class-level lock"
    assert_equal lock_a, @model_class._ct.advisory_lock_name(@model_class.new.tap { |i| i.name = "tenant_a" })
  end

  def test_symbol_advisory_lock_name
    with_temporary_model do
      has_closure_tree advisory_lock_name: :custom_lock_method

      def self.custom_lock_method
        'method_generated_lock'
      end
    end

    instance = @model_class.new
    assert_equal 'method_generated_lock', instance._ct.advisory_lock_name
  end

  def test_symbol_advisory_lock_name_raises_on_missing_method
    with_temporary_model do
      has_closure_tree advisory_lock_name: :non_existent_method
    end

    instance = @model_class.new
    assert_raises(ArgumentError) do
      instance._ct.advisory_lock_name
    end
  end

  private

  def with_temporary_model(&block)
    # Create a named temporary class
    model_name = "TempModel#{Time.now.to_i}#{rand(1000)}"
    
    @model_class = Class.new(ApplicationRecord) do
      self.table_name = 'tags'
    end
    
    # Set the constant before calling has_closure_tree
    Object.const_set(model_name, @model_class)
    
    # Create hierarchy class before calling has_closure_tree
    hierarchy_class = Class.new(ApplicationRecord) do
      self.table_name = 'tag_hierarchies'
    end
    Object.const_set("#{model_name}Hierarchy", hierarchy_class)
    
    # Now call has_closure_tree with the block
    @model_class.instance_eval(&block)
    
    # Clean up constants after test
    ObjectSpace.define_finalizer(self, proc {
      Object.send(:remove_const, model_name) if Object.const_defined?(model_name)
      Object.send(:remove_const, "#{model_name}Hierarchy") if Object.const_defined?("#{model_name}Hierarchy")
    })
  end
end
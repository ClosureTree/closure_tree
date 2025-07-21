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
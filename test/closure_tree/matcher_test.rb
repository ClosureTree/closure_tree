require 'test_helper'
require 'closure_tree/test/matcher'

class MatcherTest < ActiveSupport::TestCase
  include ClosureTree::Test::Matcher
  
  setup do
    ENV['FLOCK_DIR'] = Dir.mktmpdir
  end

  teardown do
    FileUtils.remove_entry_secure ENV['FLOCK_DIR']
  end

  test "be_a_closure_tree matcher" do
    assert_closure_tree UUIDTag
    assert_closure_tree User
    assert_closure_tree Label, ordered: true
    assert_closure_tree Metal, ordered: :sort_order
    assert_closure_tree MenuItem
    refute_closure_tree Contract
  end

  test "ordered option" do
    assert_closure_tree Label, ordered: true
    assert_closure_tree UUIDTag, ordered: true
    assert_closure_tree Metal, ordered: :sort_order
  end

  test "advisory_lock option" do
    assert_closure_tree User, with_advisory_lock: true
    assert_closure_tree Label, ordered: true, with_advisory_lock: true
    assert_closure_tree Metal, ordered: :sort_order, with_advisory_lock: true
  end

  test "without_advisory_lock option" do
    assert_closure_tree MenuItem, with_advisory_lock: false
  end

  private

  def assert_closure_tree(model, options = {})
    assert model.is_a?(Class), "Expected #{model} to be a Class"
    assert model.included_modules.include?(ClosureTree::Model), 
           "Expected #{model} to include ClosureTree::Model"
    
    if options[:ordered]
      order_column = options[:ordered] == true ? :sort_order : options[:ordered]
      assert model.closure_tree_options[:order], 
             "Expected #{model} to be ordered"
      if order_column != true
        assert_equal order_column.to_s, model.closure_tree_options[:order], 
                     "Expected #{model} to be ordered by #{order_column}"
      end
    end
    
    if options.key?(:with_advisory_lock)
      expected = options[:with_advisory_lock]
      actual = model.closure_tree_options[:with_advisory_lock]
      assert_equal expected, actual, 
                   "Expected #{model} advisory lock to be #{expected}, but was #{actual}"
    end
  end
  
  def refute_closure_tree(model)
    assert model.is_a?(Class), "Expected #{model} to be a Class"
    refute model.included_modules.include?(ClosureTree::Model), 
           "Expected #{model} not to include ClosureTree::Model"
  end
end
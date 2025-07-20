# frozen_string_literal: true

require 'test_helper'
require 'closure_tree/test/matcher'

class MatcherTest < ActiveSupport::TestCase
  include ClosureTree::Test::Matcher

  setup do
    ENV['FLOCK_DIR'] = Dir.mktmpdir
  end

  teardown do
    FileUtils.remove_entry_secure ENV.fetch('FLOCK_DIR', nil)
  end

  test 'be_a_closure_tree matcher' do
    assert_closure_tree UuidTag
    assert_closure_tree User
    assert_closure_tree Label, ordered: true
    assert_closure_tree Metal, ordered: :sort_order
    assert_closure_tree MenuItem
    refute_closure_tree Contract
  end

  test 'ordered option' do
    assert_closure_tree Label, ordered: true
    assert_closure_tree UuidTag, ordered: true
    assert_closure_tree Metal, ordered: :sort_order
  end

  test 'advisory_lock option' do
    # SQLite doesn't support advisory locks, so skip these tests when using SQLite
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('sqlite')
      skip "SQLite doesn't support advisory locks"
    else
      assert_closure_tree User, with_advisory_lock: true
      assert_closure_tree Label, ordered: true, with_advisory_lock: true
      assert_closure_tree Metal, ordered: :sort_order, with_advisory_lock: true
    end
  end

  test 'without_advisory_lock option' do
    assert_closure_tree MenuItem, with_advisory_lock: false
  end

  private

  def assert_closure_tree(model, options = {})
    assert model.is_a?(Class), "Expected #{model} to be a Class"
    assert model.respond_to?(:_ct),
           "Expected #{model} to have closure_tree enabled"

    if options[:ordered]
      order_column = options[:ordered] == true ? :sort_order : options[:ordered]
      assert model._ct.options[:order],
             "Expected #{model} to be ordered"
      if order_column != true && order_column != :sort_order
        assert_equal order_column.to_s, model._ct.options[:order],
                     "Expected #{model} to be ordered by #{order_column}"
      end
    end

    return unless options.key?(:with_advisory_lock)

    expected = options[:with_advisory_lock]
    actual = model._ct.options[:with_advisory_lock]
    if expected
      assert actual, "Expected #{model} to have advisory lock"
    else
      refute actual, "Expected #{model} not to have advisory lock"
    end
  end

  def refute_closure_tree(model)
    assert model.is_a?(Class), "Expected #{model} to be a Class"
    refute model.respond_to?(:_ct),
           "Expected #{model} not to have closure_tree enabled"
  end
end

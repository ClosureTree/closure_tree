# frozen_string_literal: true

require 'test_helper'

describe ClosureTree::Support do
  let(:model) { Tag }
  let(:sut) { model._ct }

  it 'passes through table names without prefix and suffix' do
    expected = 'some_random_table_name'
    assert_equal expected, sut.remove_prefix_and_suffix(expected)
  end

  it 'extracts through table name with prefix and suffix' do
    expected = 'some_random_table_name'
    tn = ActiveRecord::Base.table_name_prefix + expected + ActiveRecord::Base.table_name_suffix
    assert_equal expected, sut.remove_prefix_and_suffix(tn)
  end

  it 'initializes without error when with_advisory_lock is false' do
    assert ClosureTree::Support.new(model, { with_advisory_lock: false })
  end

  it 'initializes without error when with_advisory_lock is true and advisory_lock_timeout_seconds is set' do
    assert ClosureTree::Support.new(model, { with_advisory_lock: true, advisory_lock_timeout_seconds: 10 })
  end

  it 'calls :with_advisory_lock! when with_advisory_lock is true and timeout is 10' do
    options = sut.options.merge(with_advisory_lock: true, advisory_lock_timeout_seconds: 10)
    called = false
    sut.stub(:options, options) do
      model.stub(:with_advisory_lock!, ->(_lock_name, _options, &block) { block.call }) do
        sut.with_advisory_lock { called = true }
      end
    end
    assert called, 'block should have been called'
  end

  it 'calls :with_advisory_lock when with_advisory_lock is true and timeout is nil' do
    called = false
    model.stub(:with_advisory_lock, ->(_lock_name, _options, &block) { block.call }) do
      sut.with_advisory_lock { called = true }
    end
    assert called, 'block should have been called'
  end

  it 'does not call advisory lock methods when with_advisory_lock is false' do
    options = sut.options.merge(with_advisory_lock: false, advisory_lock_timeout_seconds: nil)
    called = false
    sut.stub(:options, options) do
      sut.with_advisory_lock { called = true }
    end
    assert called, 'block should have been called'
  end
end

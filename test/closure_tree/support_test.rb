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

  it 'raises ArgumentError when advisory_lock_timeout_seconds is set but with_advisory_lock is false' do
    error = assert_raises(ArgumentError) do
      ClosureTree::Support.new(model, with_advisory_lock: false, advisory_lock_timeout_seconds: 10)
    end
    assert_match(/advisory_lock_timeout_seconds can't be specified when advisory_lock is disabled/, error.message)
  end

  it 'calls :with_advisory_lock! when with_advisory_lock is true and timeout is 10' do
    options = sut.options.merge(with_advisory_lock: true, advisory_lock_timeout_seconds: 10)
    received_lock_name = nil
    received_options = nil
    called = false
    sut.stub(:options, options) do
      model.stub(:with_advisory_lock!, ->(lock_name, opts, &block) {
        received_lock_name = lock_name
        received_options = opts
        block.call
      }) do
        sut.with_advisory_lock { called = true }
      end
    end
    assert called, 'block should have been called'
    assert_equal sut.advisory_lock_name, received_lock_name, 'lock name should be passed to with_advisory_lock!'
    assert_equal({ timeout_seconds: 10 }, received_options, 'options should include timeout_seconds when timeout is configured')
  end

  it 'calls :with_advisory_lock when with_advisory_lock is true and timeout is nil' do
    received_options = nil
    called = false
    model.stub(:with_advisory_lock, ->(_lock_name, opts, &block) {
      received_options = opts
      block.call
    }) do
      sut.with_advisory_lock { called = true }
    end
    assert called, 'block should have been called'
    assert_equal({}, received_options, 'options should be empty when timeout is not configured')
  end

  it 'does not call advisory lock methods when with_advisory_lock is false' do
    options = sut.options.merge(with_advisory_lock: false, advisory_lock_timeout_seconds: nil)
    called = false
    sut.stub(:options, options) do
      sut.with_advisory_lock { called = true }
    end
    assert called, 'block should have been called'
  end

  it 'raises WithAdvisoryLock::FailedToAcquireLock when lock cannot be acquired within timeout' do
    lock_held = false
    holder_thread = Thread.new do
      model.connection_pool.with_connection do
        model.with_advisory_lock(sut.advisory_lock_name) do
          lock_held = true
          sleep 2
        end
      end
    end

    # Wait for holder to acquire the lock
    sleep 0.2 until lock_held

    support_with_timeout = ClosureTree::Support.new(
      model,
      sut.options.merge(with_advisory_lock: true, advisory_lock_timeout_seconds: 1)
    )

    assert_raises(WithAdvisoryLock::FailedToAcquireLock) do
      support_with_timeout.with_advisory_lock { nil }
    end

    holder_thread.join
  end
end

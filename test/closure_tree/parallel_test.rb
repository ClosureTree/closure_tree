# frozen_string_literal: true

require 'test_helper'

# We don't need to run the expensive parallel tests for every combination of prefix/suffix.
# Those affect SQL generation, not parallelism.
# SQLite doesn't support concurrency reliably, either.
def run_parallel_tests?
  !sqlite? &&
    ActiveRecord::Base.table_name_prefix.empty? &&
    ActiveRecord::Base.table_name_suffix.empty?
end

def max_threads
  5
end

class WorkerBase
  extend Forwardable
  attr_reader :name

  def_delegators :@thread, :join, :wakeup, :status, :to_s

  def log(msg)
    puts("#{Thread.current}: #{msg}") if ENV['VERBOSE']
  end

  def initialize(target, name)
    @target = target
    @name = name
    @thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { before_work } if respond_to? :before_work
      log 'going to sleep...'
      sleep
      log 'woke up...'
      ActiveRecord::Base.connection_pool.with_connection { work }
      log 'done.'
    end
  end
end

class FindOrCreateWorker < WorkerBase
  def work
    path = [name, :a, :b, :c]
    log "making #{path}..."
    t = (@target || Tag).find_or_create_by_path(path)
    log "made #{t.id}, #{t.ancestry_path}"
  end
end

class SiblingPrependerWorker < WorkerBase
  def before_work
    @target.reload
    @sibling = Label.new(name: SecureRandom.hex(10))
  end

  def work
    @target.prepend_sibling @sibling
  end
end

describe 'Concurrent creation' do
  before do
    @target = nil
    @iterations = 5

    # Clean up SQLite database file if it exists
    db_file = 'test/dummy/db/test.sqlite3'
    if File.exist?(db_file)
      SqliteRecord.connection.disconnect!
      File.delete(db_file)
      SqliteRecord.connection.reconnect!
    end
    Tag.delete_all
    Tag.hierarchy_class.delete_all
    User.delete_all
    User.hierarchy_class.delete_all
    Label.delete_all
    Label.hierarchy_class.delete_all
  end

  def log(msg)
    puts(msg) if ENV['VERBOSE']
  end

  def run_workers(worker_class = FindOrCreateWorker)
    @names = @iterations.times.map { |iter| "iteration ##{iter}" }
    @names.each do |name|
      workers = max_threads.times.map { worker_class.new(@target, name) }
      # Wait for all the threads to get ready:
      loop do
        unready_workers = workers.reject { |ea| ea.status == 'sleep' }
        break if unready_workers.empty?

        log "Not ready to wakeup: #{unready_workers.map { |ea| [ea.to_s, ea.status] }}"
        sleep(0.1)
      end
      sleep(0.25)
      # OK, GO!
      log 'Calling .wakeup on all workers...'
      workers.each(&:wakeup)
      sleep(0.25)
      # Then wait for them to finish:
      log 'Calling .join on all workers...'
      workers.each(&:join)
    end
    # Ensure we're still connected:
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute('SELECT 1')
    end
  end

  it 'will not create dupes from class methods' do
    skip('unsupported') unless run_parallel_tests?

    run_workers
    assert_equal @names.sort, Tag.roots.collect(&:name).sort
    # No dupe children:
    %w[a b c].each do |ea|
      assert_equal @iterations, Tag.where(name: ea).size
    end
  end

  it 'will not create dupes from instance methods' do
    skip('unsupported') unless run_parallel_tests?

    @target = Tag.create!(name: 'root')
    run_workers
    assert_equal @names.sort, @target.reload.children.collect(&:name).sort
    assert_equal @iterations, Tag.where(name: @names).size
    %w[a b c].each do |ea|
      assert_equal @iterations, Tag.where(name: ea).size
    end
  end

  it 'creates dupe roots without advisory locks' do
    skip('unsupported') unless run_parallel_tests?

    # disable with_advisory_lock:
    Tag.stub(:with_advisory_lock, ->(_lock_name, &block) { block.call }) do
      run_workers
      # duplication from at least one iteration:
      assert Tag.where(name: @names).size > @iterations
    end
  end

  it 'fails to deadlock while simultaneously deleting items from the same hierarchy' do
    skip('unsupported') unless run_parallel_tests?

    target = User.find_or_create_by_path((1..200).to_a.map(&:to_s))
    emails = target.self_and_ancestors.to_a.map(&:email).shuffle
    User.stub(:rebuild!, -> {}) do
      Parallel.map(emails, in_threads: max_threads) do |email|
        ActiveRecord::Base.connection_pool.with_connection do
          User.transaction do
            log "Destroying #{email}..."
            User.where(email: email).destroy_all
          end
        end
      end
    end
    User.connection.reconnect!
    assert User.all.empty?
  end

  it 'fails to deadlock from prepending siblings' do
    skip('unsupported') unless run_parallel_tests?

    @target = Label.find_or_create_by_path %w[root parent]
    run_workers(SiblingPrependerWorker)
    children = Label.roots
    uniq_order_values = children.collect(&:order_value).uniq
    assert_equal uniq_order_values.size, children.size

    # The only non-root node should be "root":
    assert_equal([@target.parent], Label.all.select(&:root?))
  end
end

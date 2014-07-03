require 'spec_helper'
require 'securerandom'

class WorkerBase
  def initialize(target, run_at, name)
    @target = target
    @thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        before_work
        sleep((run_at - Time.now).to_f)
        do_work(name)
      end
    end
  end

  def before_work
  end

  def work(name)
    raise
  end

  def join
    @thread.join
  end
end

class FindOrCreateWorker < WorkerBase
  def do_work(name)
    (@target || Tag).find_or_create_by_path([name.to_s, :a, :b, :c])
  end
end

describe 'Concurrent creation', if: support_concurrency do

  before :each do
    @target = nil
    @iterations = 5
    @threads = 10
  end

  def run_workers(worker_class = FindOrCreateWorker)
    all_workers = []
    @names = @iterations.times.map { |iter| "iteration ##{iter}" }
    @names.each do |name|
      wake_time = 1.second.from_now
      workers = @threads.times.map do
        worker_class.new(@target, wake_time, name)
      end
      workers.each(&:join)
      all_workers += workers
      puts name
    end
    # Ensure we're still connected:
    ActiveRecord::Base.connection_pool.connection
    all_workers
  end

  it 'will not create dupes from class methods' do
    run_workers
    expect(Tag.roots.collect { |ea| ea.name }).to match_array(@names)
    # No dupe children:
    %w(a b c).each do |ea|
      expect(Tag.where(name: ea).size).to eq(@iterations)
    end
  end

  it 'will not create dupes from instance methods' do
    @target = Tag.create!(name: 'root')
    run_workers
    expect(@target.reload.children.collect { |ea| ea.name }).to match_array(@names)
    expect(Tag.where(name: @names).size).to eq(@iterations)
    %w(a b c).each do |ea|
      expect(Tag.where(name: ea).size).to eq(@iterations)
    end
  end

  it 'creates dupe roots without advisory locks' do
    # disable with_advisory_lock:
    allow(Tag).to receive(:with_advisory_lock) { |_lock_name, &block| block.call }
    run_workers
    expect(Tag.where(name: @names).size).to be > @iterations
  end

  class SiblingPrependerWorker < WorkerBase
    def before_work
      @target.reload
      @sibling = Label.new(name: SecureRandom.hex(10))
    end

    def do_work(name)
      @target.prepend_sibling @sibling
    end
  end

  xit 'fails to deadlock from parallel sibling churn' do
    # target should be non-trivially long to maximize time spent in hierarchy maintenance
    target = Tag.find_or_create_by_path(('a'..'z').to_a + ('A'..'Z').to_a)
    expected_children = (1..100).to_a.map { |ea| "root ##{ea}" }
    children_to_add = expected_children.dup
    added_children = []
    children_to_delete = []
    deleted_children = []
    creator_threads = @workers.times.map do
      DbThread.new do
        while children_to_add.present?
          name = children_to_add.shift
          unless name.nil?
            Tag.transaction { target.find_or_create_by_path(name) }
            children_to_delete << name
            added_children << name
          end
        end
      end
    end
    run_destruction = true
    destroyer_threads = @workers.times.map do
      DbThread.new do
        begin
          victim_name = children_to_delete.shift
          if victim_name
            Tag.transaction do
              victim = target.children.where(name: victim_name).first
              victim.destroy
              deleted_children << victim_name
            end
          else
            sleep rand # wait for more victims
          end
        end while run_destruction || !children_to_delete.empty?
      end
    end
    creator_threads.each { |ea| ea.join }
    run_destruction = false
    destroyer_threads.each { |ea| ea.join }
    expect(added_children).to match(expected_children)
    expect(deleted_children).to match(expected_children)
  end

  xit 'fails to deadlock while simultaneously deleting items from the same hierarchy' do
    target = User.find_or_create_by_path((1..200).to_a.map { |ea| ea.to_s })
    to_delete = target.self_and_ancestors.to_a.shuffle.map(&:email)
    destroyer_threads = @workers.times.map do
      DbThread.new do
        until to_delete.empty?
          email = to_delete.shift
          User.transaction { User.where(email: email).first.destroy } if email
        end
      end
    end
    destroyer_threads.each { |ea| ea.join }
    expect(User.all).to be_empty
  end

  class SiblingPrependerWorker < WorkerBase
    def before_work
      @target.reload
      @sibling = Label.new(name: SecureRandom.hex(10))
    end

    def do_work(name)
      @target.prepend_sibling @sibling
    end
  end

  it 'fails to deadlock from prepending siblings' do
    @target = Label.find_or_create_by_path %w(root parent)
    run_workers(SiblingPrependerWorker)
    children = Label.roots
    uniq_order_values = children.collect { |ea| ea.order_value }.uniq
    expect(children.size).to eq(uniq_order_values.size)

    # The only non-root node should be "root":
    expect(Label.all.select { |ea| ea.root? }).to eq([@target.parent])
  end

end

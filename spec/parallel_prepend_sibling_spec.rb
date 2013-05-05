require 'spec_helper'
require 'securerandom'

describe "threadhot" do

  before :each do
    LabelHierarchy.delete_all
    Label.delete_all
    @iterations = 5
    @workers = 8
  end

  def prepend_sibling_at_even_second(run_at)
    ActiveRecord::Base.connection.reconnect!
    sibling = Label.new(:name => SecureRandom.hex(10))
    target = Label.find(@target.id)
    sleep(run_at - Time.now.to_f)
    target.prepend_sibling sibling
  end

  def run_workers
    start_time = Time.now.to_i + 2
    @times = @iterations.times.collect { |ea| start_time + (ea * 2) }
    @names = @times.collect { |ea| ea.to_s }
    @threads = @workers.times.collect do
      Thread.new do
        @times.each { |ea| prepend_sibling_at_even_second(ea) }
      end
    end
    @threads.each { |ea| ea.join }
  end

  it "prepend_sibling on a non-root node doesn't cause deadlocks" do
    @target = Label.find_or_create_by_path %w(root parent)
    run_workers
    children = Label.roots
    uniq_sort_orders = children.collect { |ea| ea.sort_order }.uniq
    children.size.should == uniq_sort_orders.size

    # The only non-root node should be "root":
    Label.all.select { |ea| ea.root? }.should == [@target.parent]
  end

# SQLite doesn't like parallelism, and Rails 3.0 and 3.1 have known threading issues. SKIP.
end if ((ENV["DB"] != "sqlite") && (ActiveRecord::VERSION::STRING =~ /^3.2/))

require 'spec_helper'

parallelism_is_broken = begin
  # Rails < 3.2 has known bugs with parallelism
  (ActiveRecord::VERSION::MAJOR <= 3 && ActiveRecord::VERSION::MINOR < 2) ||
    # SQLite doesn't support parallel writes
    ENV["DB"] =~ /sqlite/
end

describe "threadhot" do

  before :each do
    ActiveRecord::Base.connection.reconnect!
    TagHierarchy.delete_all
    Tag.delete_all
    @iterations = 5
    @workers = 6 # Travis CI workers can't reliably handle larger numbers
    @parent = nil
    @time_between_runs = 1
  end

  def find_or_create_at_even_second(run_at)
    sleep(run_at - Time.now.to_f)
    ActiveRecord::Base.connection.reconnect!
    (@parent || Tag).find_or_create_by_path([run_at.to_s, :a, :b, :c])
  end

  def run_workers
    expected_thread_setup_time = 4
    start_time = Time.now.to_i + expected_thread_setup_time
    @times = @iterations.times.collect { |ea| start_time + (ea * @time_between_runs) }
    @names = @times.collect { |ea| ea.to_s }
    @threads = @workers.times.collect do
      Thread.new do
        @times.each { |ea| find_or_create_at_even_second(ea) }
      end
    end
    @threads.each { |ea| ea.join }
  end

  it "class method will not create dupes" do
    run_workers
    Tag.roots.collect { |ea| ea.name.to_i }.should =~ @times
    # No dupe children:
    %w(a b c).each do |ea|
      Tag.where(:name => ea).size.should == @iterations
    end
  end

  it "instance method will not create dupes" do
    @parent = Tag.create!(:name => "root")
    run_workers
    @parent.reload.children.collect { |ea| ea.name.to_i }.should =~ @times
    Tag.where(:name => @names).size.should == @iterations
    %w(a b c).each do |ea|
      Tag.where(:name => ea).size.should == @iterations
    end
  end

  it "creates dupe roots without advisory locks" do
    # disable with_advisory_lock:
    Tag.stub(:with_advisory_lock).and_return { |lock_name, &block| block.call }
    run_workers
    Tag.where(:name => @names).size.should > @iterations
  end

  it "fails to deadlock from parallel sibling churn" do
    # target should be non-trivially long to maximize time spent in hierarchy maintenance
    target = Tag.find_or_create_by_path(('a'..'z').to_a + ('A'..'Z').to_a)
    expected_children = (1..100).to_a.map { |ea| "root ##{ea}" }
    children_to_add = expected_children.dup
    added_children = []
    children_to_delete = []
    deleted_children = []
    creator_threads = @workers.times.map do
      Thread.new do
        ActiveRecord::Base.connection.reconnect!
        begin
          name = children_to_add.shift
          unless name.nil?
            target.find_or_create_by_path(name)
            children_to_delete << name
            added_children << name
          end
        end while !children_to_add.empty?
      end
    end
    run_destruction = true
    destroyer_threads = @workers.times.map do
      Thread.new do
        ActiveRecord::Base.connection.reconnect!
        begin
          victim = children_to_delete.shift
          if victim
            target.children.where(:name => victim).first.destroy
            deleted_children << victim
          else
            sleep rand # wait for moar victims
          end
        end while run_destruction || !children_to_delete.empty?
      end
    end
    creator_threads.each { |ea| ea.join }
    run_destruction = false
    destroyer_threads.each { |ea| ea.join }

    added_children.should =~ expected_children
    deleted_children.should =~ expected_children
  end

  # Oh, yeah, I'm totes monkey patching in a bad shuffle. I AM A NAUGHTY MONKAY
  class Array
    def bad_shuffle!(shuffle_count = nil)
      shuffle_count ||= size / 10
      pairs = Hash[*(0..(size)).to_a.shuffle.first(shuffle_count)]
      pairs.each do |from, to|
        self[from], self[to] = self[to], self[from]
      end
      self
    end
  end

  it "fails to deadlock while simultaneously deleting items from the same hierarchy" do
    target = User.find_or_create_by_path((1..200).to_a.map { |ea| ea.to_s })
    nodes_to_delete = target.self_and_ancestors.to_a.bad_shuffle!
    destroyer_threads = @workers.times.map do
      Thread.new do
        ActiveRecord::Base.connection.reconnect!
        begin
          victim = nodes_to_delete.shift
          victim.destroy if victim
        end while !nodes_to_delete.empty?
      end
    end
    destroyer_threads.each { |ea| ea.join }
    User.all.should be_empty
  end

end unless parallelism_is_broken

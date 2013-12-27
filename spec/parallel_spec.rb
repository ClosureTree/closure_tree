require 'spec_helper'

parallelism_is_broken = begin
  # Rails < 3.2 has known bugs with parallelism
  (ActiveRecord::VERSION::MAJOR <= 3 && ActiveRecord::VERSION::MINOR < 2) ||
    # SQLite doesn't support parallel writes
    ENV["DB"] =~ /sqlite/
end

class DbThread
  def initialize(wrap_with_transaction = true, &block)
    @thread = Thread.new do
      begin
        ActiveRecord::Base.connection.reconnect!
        if wrap_with_transaction
          ActiveRecord::Base.connection.transaction { block.call }
        else
          block.call
        end
      ensure
        ActiveRecord::Base.connection.close
      end
    end
  end

  def join
    @thread.join
  end
end

describe "threadhot" do

  before :each do
    @parent = nil
    @iterations = 1
    @workers = 10
    @min_sleep_time = 0.5
    @lock = Mutex.new
    @wake_times = []
    DatabaseCleaner.clean
  end

  def find_or_create_at_same_time
    @lock.synchronize { @wake_times << Time.now.to_f + @min_sleep_time }
    while @wake_times.size < @workers
      sleep(0.1)
    end
    max_wait_time = @lock.synchronize { @wake_times.max }
    sleep_time = max_wait_time - Time.now.to_f
    $stderr.puts "sleeping for #{sleep_time}"
    sleep(sleep_time)
    (@parent || Tag).find_or_create_by_path([max_wait_time.to_i.to_s, :a, :b, :c])
  end

  def run_workers
    @names = []
    @iterations.times.each do
      threads = @workers.times.map do
        DbThread.new { find_or_create_at_same_time }
      end
      threads.each { |ea| ea.join }
      @names << @wake_times.max.to_i.to_s
      @wake_times.clear
    end
  end

  it "class method will not create dupes" do
    run_workers
    Tag.roots.collect { |ea| ea.name }.should =~ @names
    # No dupe children:
    %w(a b c).each do |ea|
      Tag.where(:name => ea).size.should == @iterations
    end
  end

  it "instance method will not create dupes" do
    @parent = Tag.create!(:name => "root")
    run_workers
    @parent.reload.children.collect { |ea| ea.name }.should =~ @names
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

  it 'fails to deadlock from parallel sibling churn' do
    # target should be non-trivially long to maximize time spent in hierarchy maintenance
    target = Tag.find_or_create_by_path(('a'..'z').to_a + ('A'..'Z').to_a)
    expected_children = (1..100).to_a.map { |ea| "root ##{ea}" }
    children_to_add = expected_children.dup
    added_children = []
    children_to_delete = []
    deleted_children = []
    creator_threads = @workers.times.map do
      DbThread.new(false) do
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
      DbThread.new(false) do
        begin
          victim_name = children_to_delete.shift
          if victim_name
            Tag.transaction do
              victim = target.children.where(:name => victim_name).first
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
    added_children.should =~ expected_children
    deleted_children.should =~ expected_children
  end

  it "fails to deadlock while simultaneously deleting items from the same hierarchy" do
    target = User.find_or_create_by_path((1..200).to_a.map { |ea| ea.to_s })
    to_delete = target.self_and_ancestors.to_a.shuffle.map(&:email)
    destroyer_threads = @workers.times.map do
      DbThread.new(false) do
        until to_delete.empty?
          email = to_delete.shift
          User.transaction { User.where(:email => email).first.destroy } if email
        end
      end
    end
    destroyer_threads.each { |ea| ea.join }
    User.all.should be_empty
  end

end unless parallelism_is_broken

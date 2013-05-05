require 'spec_helper'

describe "threadhot" do

  before :each do
    TagHierarchy.delete_all
    Tag.delete_all
    @iterations = 5
    @workers = 6 # Travis CI workers can't reliably handle larger numbers
    @parent = nil
  end

  def find_or_create_at_even_second(run_at)
    sleep(run_at - Time.now.to_f)
    ActiveRecord::Base.connection.reconnect!
    (@parent || Tag).find_or_create_by_path([run_at.to_s, :a, :b, :c].compact)
  end

  def run_workers
    start_time = Time.now.to_i + 2
    @times = @iterations.times.collect { |ea| start_time + (ea * 2) }
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
      Tag.find_all_by_name(ea).size.should == @iterations
    end
  end

  it "instance method will not create dupes" do
    @parent = Tag.create!(:name => "root")
    run_workers
    @parent.reload.children.collect { |ea| ea.name.to_i }.should =~ @times
    Tag.find_all_by_name(@names).size.should == @iterations
    %w(a b c).each do |ea|
      Tag.find_all_by_name(ea).size.should == @iterations
    end
  end

  it "creates dupe roots without advisory locks" do
    # disable with_advisory_lock:
    Tag.should_receive(:with_advisory_lock).any_number_of_times { |lock_name, &block| block.call }
    run_workers
    Tag.find_all_by_name(@names).size.should > @iterations
  end

# SQLite doesn't like parallelism, and Rails 3.0 and 3.1 have known threading issues. SKIP.
end if ((ENV["DB"] != "sqlite") && (ActiveRecord::VERSION::STRING =~ /^3.2/))

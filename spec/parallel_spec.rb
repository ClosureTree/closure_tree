require 'spec_helper'

describe "threadhot" do
  def find_or_create_at_even_second(run_at)
    sleep(run_at - Time.now.to_f)
    Tag.connection.reconnect!
    Tag.find_or_create_by_path([run_at.to_s, :a, :b, :c])
  end

  def run_workers
    start_time = Time.now.to_i + 2
    @times = (start_time + 1 .. start_time + @iterations).to_a
    @roots = @times.collect { |ea| ea.to_s }
    @threads = @workers.times.collect do
      Thread.new do
        @times.each { |ea| find_or_create_at_even_second(ea) }
      end
    end
    @threads.each { |ea| ea.join }
  end

  before :each do
    TagHierarchy.delete_all
    Tag.delete_all
    @iterations = 5
    @workers = 7
  end

  it "will not create dupe roots" do
    run_workers
    Tag.find_all_by_name(@roots).size.should == @iterations
    Tag.roots.collect { |ea| ea.name.to_i }.should =~ @times
    %w(a b c).each do |ea|
      Tag.find_all_by_name(ea).size.should == @iterations
      Tag.find_all_by_name(ea).collect { |ea| ea.root.name }.should =~ @roots
    end
  end

  it "creates dupe roots without advisory locks" do
    # disable with_advisory_lock:
    Tag.should_receive(:with_advisory_lock).any_number_of_times { |lock_name, &block| block.call }
    run_workers
    Tag.find_all_by_name(@roots).size.should > @iterations
  end
end
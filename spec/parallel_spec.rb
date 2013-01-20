require 'spec_helper'

describe "threadhot" do
  def find_or_create_at_even_second(run_at)
    Tag.connection.close
    sleep(run_at - Time.now.to_f)
    Tag.connection.reconnect!
    Tag.find_or_create_by_path([run_at.to_s, :a, :b, :c])
    Tag.rebuild!
  end

  def run_workers
    start_time = Time.now.to_i + 2
    @times = @iterations.times.collect { |ea| start_time + (ea * 2) }
    @roots = @times.collect { |ea| ea.to_s }
    @threads = @workers.times.collect do
      Thread.new do
        begin
          @times.each { |ea| find_or_create_at_even_second(ea) }
        ensure
          ActiveRecord::Base.connection.close
        end
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
    %w(a b c).each do |ea|
      Tag.find_all_by_name(ea).size.should == @iterations
      Tag.find_all_by_name(ea).collect { |ea| ea.root.name }.should =~ @roots
    end
  end
end
# Derived from http://stackoverflow.com/a/13423584/153896. Updated for RSpec 3.
RSpec::Matchers.define :exceed_query_limit do |expected|
  supports_block_expectations

  match do |block|
    query_count(&block) > expected
  end

  failure_message_when_negated do |actual|
    "Expected to run maximum #{expected} queries, got #{@counter.query_count}"
  end

  def query_count(&block)
    @counter = ActiveRecord::QueryCounter.new
    ActiveSupport::Notifications.subscribed(@counter.to_proc, 'sql.active_record', &block)
    @counter.query_count
  end
end

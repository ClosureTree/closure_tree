# frozen_string_literal: true

# See http://stackoverflow.com/a/22388177/1268016
def count_queries(&block)
  count = 0
  counter_fn = lambda do |_name, _started, _finished, _unique_id, payload|
    count += 1 unless %w[CACHE SCHEMA].include? payload[:name]
  end
  ActiveSupport::Notifications.subscribed(counter_fn, 'sql.active_record', &block)
  count
end

# frozen_string_literal: true

# https://stackoverflow.com/a/43810063/1683557

module QueryCounter
  def sql_queries(&)
    queries = []
    counter = lambda { |*, payload|
      queries << payload.fetch(:sql) unless %w[CACHE SCHEMA].include?(payload.fetch(:name))
    }

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)

    queries
  end

  def assert_database_queries_count(expected, &)
    queries = sql_queries(&)
    assert_equal(
      expected,
      queries.count,
      "Expected #{expected} queries, but found #{queries.count}:\n#{queries.join("\n")}"
    )
  end
end

# frozen_string_literal: true

# https://stackoverflow.com/a/43810063/1683557

module QueryCounter
  def sql_queries(&block)
    queries = []
    counter = lambda { |*, payload|
      queries << payload.fetch(:sql) unless %w[CACHE SCHEMA].include?(payload.fetch(:name))
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)

    queries
  end

  def assert_database_queries_count(expected, &block)
    queries = sql_queries(&block)
    queries.count.must_equal(
      expected,
      "Expected #{expected} queries, but found #{queries.count}:\n#{queries.join("\n")}"
    )
  end
end

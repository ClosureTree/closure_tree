DB_QUERIES = []

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  def log_with_query_append(query, *args, &block)
    DB_QUERIES << query
    log_without_query_append(query, *args, &block)
  end

  alias_method_chain :log, :query_append
end

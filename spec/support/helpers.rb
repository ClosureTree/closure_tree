def sqlite?
  ENV['DB'] =~ /sqlite/
end

def support_concurrency
  # SQLite doesn't support parallel writes
  !sqlite?
end

ClosureTree.configure do |config|
  # Some PaaS like Heroku don't have available the db in some build steps like
  # assets:precompile, this is skipped when this value is true, default = false
  # config.database_less = true
end

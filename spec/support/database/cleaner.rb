DatabaseCleaner.strategy = :transaction
RSpec.configure do |config|

  config.before(:each) do
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
    DB_QUERIES.clear
  end

end

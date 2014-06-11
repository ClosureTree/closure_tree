RSpec.configure do |config|

  DatabaseCleaner.strategy = :truncation

  config.before(:each) do
    ActiveRecord::Base.connection_pool.connection
    DatabaseCleaner.start
  end

  config.after(:each) do
    ActiveRecord::Base.connection_pool.connection
    DatabaseCleaner.clean
  end
end

DatabaseCleaner.strategy = :truncation

RSpec.configure do |config|

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

end

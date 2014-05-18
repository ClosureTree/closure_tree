if sqlite?
  RSpec.configure do |config|
    config.before(:suite) do
      ENV['FLOCK_DIR'] = Dir.mktmpdir
    end
    config.after(:suite) do
      FileUtils.remove_entry_secure ENV['FLOCK_DIR']
    end
  end
end
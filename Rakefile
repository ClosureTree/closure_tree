begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

Bundler::GemHelper.install_tasks

require 'yard'
YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb', 'README.md']
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :all_spec_flavors do
  [["", ""], ["db_prefix_", ""], ["", "_db_suffix"], ["abc_", "_123"]].each do |prefix, suffix|
    fail unless system("bundle exec rake spec DB_PREFIX=#{prefix} DB_SUFFIX=#{suffix}")
  end
  require 'active_record/version'
  if ActiveRecord::VERSION::MAJOR == 3
    fail unless system("rake spec ATTR_ACCESSIBLE=1")
  end
end

# Run the specs using all the different database engines:
# for DB in sqlite3 mysql postgresql ; do rake ; done

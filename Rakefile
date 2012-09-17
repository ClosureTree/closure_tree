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

task :specs_with_db_ixes do
  [["", ""], ["db_prefix_", ""], ["", "_db_suffix"], ["abc_", "_123"]].each do |prefix, suffix|
    fail unless system("rake spec DB_PREFIX=#{prefix} DB_SUFFIX=#{suffix}")
  end
end

# Run the specs using all the different database engines:
# for DB in sqlite3 mysql postgresql ; do rake ; done

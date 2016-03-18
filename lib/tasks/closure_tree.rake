require 'benchmark'
require 'sequel'

namespace :closure_tree do
  desc 'Rebuild hierarchy (TABLE, HIERARCHIES, DATABASE_URL, PARENT_ID, ID)'
  task rebuild: :environment do
    puts Benchmark.measure {
      db = Sequel.connect(ActiveRecord::Base.connection_config)

      ClosureTree::Rebuild::Runner.new(
        db, ENV['TABLE'], ENV['HIERARCHIES'], ENV['PARENT_ID'], ENV['ID']
      ).run
    }
  end
end

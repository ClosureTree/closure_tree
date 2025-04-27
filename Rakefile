# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/closure_tree/*_spec.rb'
end

namespace :spec do
  desc 'Run all spec variants'
  task :all do
    rake = 'bin/rake'

    [['', ''], ['db_prefix_', ''], ['', '_db_suffix'], %w[abc_ _123]].each do |prefix, suffix|
      env = "DB_PREFIX=#{prefix} DB_SUFFIX=#{suffix}"
      raise unless system("#{rake} spec #{env}")
    end
  end
end

Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.libs.push 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

task default: %i[spec:all test]

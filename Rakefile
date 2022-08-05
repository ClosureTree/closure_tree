# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/closure_tree/*_spec.rb'
end

task default: [:spec, :test]

namespace :spec do
  desc 'Run all spec variants'
  task :all do
    rake = 'bin/rake'
    fail unless system("#{rake} spec:generators")

    [['', ''], ['db_prefix_', ''], ['', '_db_suffix'], ['abc_', '_123']].each do |prefix, suffix|
      env = "DB_PREFIX=#{prefix} DB_SUFFIX=#{suffix}"
      fail unless system("#{rake} spec #{env}")
    end
  end

  desc 'Run generator specs'
  RSpec::Core::RakeTask.new(:generators) do |task|
    task.pattern = 'spec/generators/*_spec.rb'
  end
end

Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.libs.push 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

require 'github_changelog_generator/task'
GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'ClosureTree'
  config.project = 'closure_tree'
  config.issues = false
  config.future_release = '5.2.0'
  config.since_tag = 'v7.4.0'
end

task :default => "spec:all"
# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'spec/closure_tree/*_spec.rb'
end

task default: :spec

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

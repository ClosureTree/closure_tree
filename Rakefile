# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

task default: :test

Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.libs.push 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

namespace :test do
  desc 'Run all test variants'
  task :all do
    rake = 'bin/rake'

    [['', ''], ['db_prefix_', ''], ['', '_db_suffix'], %w[abc_ _123]].each do |prefix, suffix|
      env = "DB_PREFIX=#{prefix} DB_SUFFIX=#{suffix}"
      raise unless system("#{rake} test #{env}")
    end
  end
end

require_relative 'test/dummy/config/application'

Rails.application.load_tasks

$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)


ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
require 'rspec'
require 'active_record'
require 'foreigner'
require 'database_cleaner'
require 'closure_tree'
require 'tmpdir'


Thread.abort_on_exception = true

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.configure do |config|
  config.filter_run_excluding concurrency: true
end

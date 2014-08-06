$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
require 'rspec'
require 'active_record'
require 'foreigner'
require 'database_cleaner'
require 'closure_tree'
require 'closure_tree/test/matcher'
require 'tmpdir'
require 'timecop'
require 'forwardable'
require 'securerandom'
require 'parallel'

Thread.abort_on_exception = true

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.configure do |config|
  config.include ClosureTree::Test::Matcher
end

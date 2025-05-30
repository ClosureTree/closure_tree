# frozen_string_literal: true

require File.expand_path('boot', __dir__)

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'

Bundler.require(*Rails.groups)
require 'closure_tree'

module Dummy
  class Application < Rails::Application
    config.load_defaults [Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join('.')
    config.eager_load = false

    # Test environment settings
    config.consider_all_requests_local = true
    config.action_controller.perform_caching = false
    config.action_dispatch.show_exceptions = false
  end
end

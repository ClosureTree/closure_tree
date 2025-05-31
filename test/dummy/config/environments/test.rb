# frozen_string_literal: true

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.action_dispatch.show_exceptions = false
  config.active_support.deprecation = :stderr
  config.active_support.test_order = :random
  config.active_record.maintain_test_schema = false
end

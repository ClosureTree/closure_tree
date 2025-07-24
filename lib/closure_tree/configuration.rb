# frozen_string_literal: true

module ClosureTree
  # Minimal configuration class to handle deprecated options
  class Configuration
    def database_less=(_value)
      ActiveSupport::Deprecation.new.warn(
        'ClosureTree.configure { |config| config.database_less = true } is deprecated ' \
        'and will be removed in v10.0.0. The database_less option is no longer needed ' \
        'for modern deployment practices. Remove this configuration from your initializer.'
      )
      # Ignore the value - this is a no-op for backward compatibility
    end

    def database_less?
      false # Always return false since this option does nothing
    end

    # Keep the old method name for backward compatibility
    alias database_less database_less?
  end
end

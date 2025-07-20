# frozen_string_literal: true

module ClosureTree
  module AdapterSupport
    extend ActiveSupport::Concern

    # This module is now only used to ensure the adapter has been loaded
    # The actual advisory lock functionality is handled through the model's
    # with_advisory_lock method from the with_advisory_lock gem
  end
end

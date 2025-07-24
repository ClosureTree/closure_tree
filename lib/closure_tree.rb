# frozen_string_literal: true

require 'active_record'
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module ClosureTree
  def self.configure
    if block_given?
      # Create a temporary configuration object to capture deprecated settings
      config = Configuration.new
      yield config
    else
      ActiveSupport::Deprecation.new.warn(
        'ClosureTree.configure is deprecated and will be removed in a future version. ' \
        'Configuration is no longer needed.'
      )
    end
  end
end

ActiveSupport.on_load(:active_record) do
  extend ClosureTree::HasClosureTree, ClosureTree::HasClosureTreeRoot
end

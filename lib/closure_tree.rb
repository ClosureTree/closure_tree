# frozen_string_literal: true

require 'active_record'
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module ClosureTree
  def self.configure
    ActiveSupport::Deprecation.new.warn(
      'ClosureTree.configure is deprecated and will be removed in a future version. ' \
      'Configuration is no longer needed.'
    )
    yield if block_given?
  end
end

ActiveSupport.on_load(:active_record) do
  extend ClosureTree::HasClosureTree, ClosureTree::HasClosureTreeRoot
end

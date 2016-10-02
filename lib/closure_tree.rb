require 'active_record'

module ClosureTree
  extend ActiveSupport::Autoload

  autoload :HasClosureTree
  autoload :HasClosureTreeRoot
  autoload :Support
  autoload :HierarchyMaintenance
  autoload :Model
  autoload :Finders
  autoload :HashTree
  autoload :Digraphs
  autoload :DeterministicOrdering
  autoload :NumericDeterministicOrdering
  autoload :Configuration

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :extend, ClosureTree::HasClosureTree
  ActiveRecord::Base.send :extend, ClosureTree::HasClosureTreeRoot
end

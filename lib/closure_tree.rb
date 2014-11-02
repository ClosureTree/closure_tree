require 'active_support'

module ClosureTree
  extend ActiveSupport::Autoload

  autoload :HasClosureTree
  autoload :Support
  autoload :HierarchyMaintenance
  autoload :Model
  autoload :Finders
  autoload :HashTree
  autoload :Digraphs
  autoload :DeterministicOrdering
  autoload :NumericDeterministicOrdering
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :extend, ClosureTree::HasClosureTree
end

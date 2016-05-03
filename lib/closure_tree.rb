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
  autoload :Rebuild
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :extend, ClosureTree::HasClosureTree
end

if defined?(Rails)
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(File.dirname(__FILE__), 'tasks/closure_tree.rake')
    end
  end
end

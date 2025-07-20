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
  autoload :AdapterSupport

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.extend ClosureTree::HasClosureTree
  ActiveRecord::Base.extend ClosureTree::HasClosureTreeRoot
end

# Adapter injection for different database types
ActiveSupport.on_load :active_record_postgresqladapter do
  prepend ClosureTree::AdapterSupport
end

ActiveSupport.on_load :active_record_mysql2adapter do
  prepend ClosureTree::AdapterSupport
end

ActiveSupport.on_load :active_record_trilogyadapter do
  prepend ClosureTree::AdapterSupport
end

ActiveSupport.on_load :active_record_sqlite3adapter do
  prepend ClosureTree::AdapterSupport
end

module ClosureTree
  module Generators # :nodoc:
    class ConfigGenerator < Rails::Generators::Base # :nodoc:
      source_root File.expand_path('../templates', __FILE__)
      desc 'Install closure tree config.'

      def config
        template 'config.rb', 'config/initializers/closure_tree_config.rb'
      end
    end
  end
end

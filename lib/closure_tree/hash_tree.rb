module ClosureTree
  module HashTree
    extend ActiveSupport::Concern

    def hash_tree(options = {})
      _ct.hash_tree(self_and_descendants, options[:limit_depth])
    end

    module ClassMethods

      # There is no default depth limit. This might be crazy-big, depending
      # on your tree shape. Hash huge trees at your own peril!
      def hash_tree(options = {})
        _ct.hash_tree(_ct.default_tree_scope(all, options[:limit_depth]))
      end
    end
  end
end

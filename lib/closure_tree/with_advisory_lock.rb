require 'with_advisory_lock'

module ClosureTree
  module WithAdvisoryLock
    def ct_with_advisory_lock(&block)
      if closure_tree_options[:with_advisory_lock]
        with_advisory_lock("closure_tree") do
          transaction do
            yield
          end
        end
      else
        yield
      end
    end
  end
end


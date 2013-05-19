require 'with_advisory_lock'
require 'active_support/concern'

module ClosureTree
  module WithAdvisoryLock
    extend ActiveSupport::Concern

    def ct_with_advisory_lock(&block)
      self.class.ct_with_advisory_lock(&block)
    end

    included do
      class_eval do
        def self.ct_with_advisory_lock(&block)
          if _ct.options[:with_advisory_lock]
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
  end
end

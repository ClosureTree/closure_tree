# frozen_string_literal: true

module ClosureTree
  module AdapterSupport
    extend ActiveSupport::Concern

    def with_closure_tree_advisory_lock(lock_name, &)
      if supports_advisory_locks?
        with_advisory_lock("closure_tree:#{lock_name}", &)
      else
        # For adapters that don't support advisory locks (like SQLite),
        # just yield without locking
        yield
      end
    end
  end
end

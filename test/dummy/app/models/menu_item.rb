# frozen_string_literal: true

class MenuItem < ApplicationRecord
  has_closure_tree touch: true, with_advisory_lock: false
end

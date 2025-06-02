# frozen_string_literal: true

module Namespace
  class Type < ApplicationRecord
    has_closure_tree dependent: :destroy
  end
end

# frozen_string_literal: true

class Group < ApplicationRecord
  has_closure_tree_root :root_user
end

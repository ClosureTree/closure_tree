# frozen_string_literal: true

class UserSet < ApplicationRecord
  has_closure_tree_root :root_user, class_name: 'User'
end

# frozen_string_literal: true

class Team < ApplicationRecord
  has_closure_tree_root :root_user, class_name: 'User', foreign_key: :grp_id
end

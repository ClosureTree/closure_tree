# frozen_string_literal: true

class Grouping < ApplicationRecord
  has_closure_tree_root :root_person, class_name: 'User', foreign_key: :group_id
end

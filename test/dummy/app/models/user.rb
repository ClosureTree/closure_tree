# frozen_string_literal: true

class User < ApplicationRecord
  acts_as_tree parent_column_name: 'referrer_id',
               name_column: 'email',
               hierarchy_class_name: 'ReferralHierarchy',
               hierarchy_table_name: 'referral_hierarchies'

  has_many :contracts, inverse_of: :user
  belongs_to :group, optional: true

  def indirect_contracts
    Contract.where(user_id: descendant_ids)
  end

  def to_s
    email
  end
end

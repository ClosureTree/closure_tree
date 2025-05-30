# frozen_string_literal: true

class Contract < ApplicationRecord
  belongs_to :user, inverse_of: :contracts
  belongs_to :contract_type, inverse_of: :contracts, optional: true
end

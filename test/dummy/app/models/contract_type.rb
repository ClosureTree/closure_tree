# frozen_string_literal: true

class ContractType < ApplicationRecord
  has_many :contracts, inverse_of: :contract_type
end

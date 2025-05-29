# frozen_string_literal: true

class Tag < ApplicationRecord
  after_save do
    TagAudit.create(tag_name: name)
    Label.create(name: name)
  end
end

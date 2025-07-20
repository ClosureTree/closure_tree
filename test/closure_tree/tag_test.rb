# frozen_string_literal: true

require 'test_helper'
require 'support/tag_examples'

class TagTest < ActiveSupport::TestCase
  TAG_CLASS = Tag
  include TagExamples
end

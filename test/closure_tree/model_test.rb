# frozen_string_literal: true

require 'test_helper'

describe '#_ct' do
  it 'should delegate to the Support instance on the class' do
    assert_equal Tag._ct, Tag.new._ct
  end
end

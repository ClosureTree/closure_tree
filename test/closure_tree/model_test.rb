# frozen_string_literal: true

require 'test_helper'

describe '#_ct' do
  it 'should delegate to the Support instance on the class' do
    assert_equal Tag._ct, Tag.new._ct
  end
end

describe 'multi database support' do
  it 'should have a different connection for menu items' do
    # These 2 models are in the same database
    assert_equal Tag.connection, Metal.connection
    # The hierarchy table is in the same database
    assert_equal Tag.connection, TagHierarchy.connection

    # However, these 2 models are in different databases
    refute_equal MenuItem.connection, Tag.connection
    # The hierarchy table is in the same database
    assert_equal MenuItem.connection, MenuItemHierarchy.connection
  end
end

# frozen_string_literal: true

require 'test_helper'

def assert_lineage(e, m)
  assert_equal e, m.parent
  assert_equal [m, e], m.self_and_ancestors

  # make sure reloading doesn't affect the self_and_ancestors:
  m.reload
  assert_equal [m, e], m.self_and_ancestors
end

describe CuisineType do
  it 'finds self and parents when children << is used' do
    e = CuisineType.new(name: 'e')
    m = CuisineType.new(name: 'm')
    e.children << m
    e.save
    assert_lineage(e, m)
  end

  it 'finds self and parents properly if the constructor is used' do
    e = CuisineType.create(name: 'e')
    m = CuisineType.create(name: 'm', parent: e)
    assert_lineage(e, m)
  end

  it 'sets the table_name of the hierarchy class properly' do
    assert_equal(
      "#{ActiveRecord::Base.table_name_prefix}cuisine_type_hierarchies#{ActiveRecord::Base.table_name_suffix}", CuisineTypeHierarchy.table_name
    )
  end

  it 'fixes self_and_ancestors properly on reparenting' do
    a = CuisineType.create! name: 'a'
    b = CuisineType.create! name: 'b'
    assert_equal([b], b.self_and_ancestors.to_a)
    a.children << b
    assert_equal([b, a], b.self_and_ancestors.to_a)
  end
end

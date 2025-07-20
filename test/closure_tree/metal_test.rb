# frozen_string_literal: true

require 'test_helper'

describe Metal do
  describe '#find_or_create_by_path' do
    def assert_correctness(grandchild)
      assert(Metal, grandchild)
      assert_equal 'slag', grandchild.description
      child = grandchild.parent
      assert(Unobtanium, child)
      assert_equal 'frames', child.description
      assert_equal 'child', child.value
      parent = child.parent
      assert(Adamantium, parent)
      assert_equal 'claws', parent.description
      assert_equal 'parent', parent.value
    end

    let(:attr_path) do
      [
        { value: 'parent', description: 'claws', metal_type: 'Adamantium' },
        { value: 'child', description: 'frames', metal_type: 'Unobtanium' },
        { value: 'grandchild', description: 'slag', metal_type: 'Metal' }
      ]
    end

    it 'creates children from the proper root' do
      assert_correctness(Metal.find_or_create_by_path(attr_path))
    end

    it 'supports STI from the base class' do
      assert_correctness(Metal.find_or_create_by_path(attr_path))
    end

    it 'supports STI from a subclass' do
      parent = Adamantium.create!(value: 'parent', description: 'claws')
      assert_correctness(parent.find_or_create_by_path(attr_path.last(2)))
    end

    it 'maintains the current STI subclass if attributes are not specified' do
      leaf = Unobtanium.find_or_create_by_path(%w[a b c d])
      assert(Unobtanium, leaf)
      assert_equal %w[c b a], leaf.ancestors.map(&:value)
      leaf.ancestors.each do |anc|
        assert(Unobtanium, anc)
      end
    end
  end
end

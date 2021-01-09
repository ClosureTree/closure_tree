require 'spec_helper'

RSpec.describe Metal do
  describe '#find_or_create_by_path' do
    def assert_correctness(grandchild)
      expect(grandchild).to be_a(Metal)
      expect(grandchild.description).to eq('slag')
      child = grandchild.parent
      expect(child).to be_a(Unobtanium)
      expect(child.description).to eq('frames')
      expect(child.value).to eq('child')
      parent = child.parent
      expect(parent).to be_a(Adamantium)
      expect(parent.description).to eq('claws')
      expect(parent.value).to eq('parent')
    end

    let(:attr_path) do
      [
        {value: 'parent', description: 'claws', metal_type: 'Adamantium'},
        {value: 'child', description: 'frames', metal_type: 'Unobtanium'},
        {value: 'grandchild', description: 'slag', metal_type: 'Metal'}
      ]
    end

    before do
      # ensure the correct root is used in find_or_create_by_path:
      [Metal, Adamantium, Unobtanium].each do |metal|
        metal.find_or_create_by_path(%w(parent child grandchild))
      end
    end if false

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
      leaf = Unobtanium.find_or_create_by_path(%w(a b c d))
      expect(leaf).to be_a(Unobtanium)
      expect(leaf.ancestors.map(&:value)).to eq(%w(c b a))
      leaf.ancestors.each do |anc|
        expect(anc).to be_a(Unobtanium)
      end
    end
  end
end

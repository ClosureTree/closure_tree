require 'spec_helper'

RSpec.describe ClosureTree::Model do
  describe '#_ct' do
    it 'should delegate to the Support instance on the class' do
      expect(Tag.new._ct).to eq(Tag._ct)
    end
  end
end

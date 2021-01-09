require 'spec_helper'

RSpec.describe 'ClosureTree::Test::Matcher' do
  describe 'be_a_closure_tree' do
    it { expect(UUIDTag).to be_a_closure_tree }
    it { expect(User).to be_a_closure_tree }
    it { expect(Label).to be_a_closure_tree.ordered }
    it { expect(Metal).to be_a_closure_tree.ordered(:sort_order) }
    it { expect(MenuItem).to be_a_closure_tree }
    it { expect(Contract).not_to be_a_closure_tree }
  end

  describe 'ordered' do
    it { expect(Label).to be_a_closure_tree.ordered }
    it { expect(UUIDTag).to be_a_closure_tree.ordered }
    it { expect(Metal).to be_a_closure_tree.ordered(:sort_order) }
  end

  describe 'advisory_lock' do
    it 'should use advisory lock' do
      expect(User).to be_a_closure_tree.with_advisory_lock
      expect(Label).to be_a_closure_tree.ordered.with_advisory_lock
      expect(Metal).to be_a_closure_tree.ordered(:sort_order).with_advisory_lock
    end

    describe MenuItem do
      it 'should not use advisory lock' do
        is_expected.to be_a_closure_tree.without_advisory_lock
      end
    end
  end
end

require 'spec_helper'

describe 'ClosureTree::Test::Matcher' do

  describe 'be_a_closure_tree' do
    it { UUIDTag.should be_a_closure_tree }
    it { User.should be_a_closure_tree }
    it { Label.should be_a_closure_tree.ordered }
    it { Metal.should be_a_closure_tree.ordered(:sort_order) }
    it { MenuItem.should be_a_closure_tree }

    it { Contract.should_not be_a_closure_tree }
  end


  describe 'ordered' do
    it { Label.should be_a_closure_tree.ordered }
    it { UUIDTag.should be_a_closure_tree.ordered }
    it { Metal.should be_a_closure_tree.ordered(:sort_order) }
  end

  describe 'advisory_lock' do
    it 'should use advisory lock' do
      User.should be_a_closure_tree.with_advisory_lock
      Label.should be_a_closure_tree.ordered.with_advisory_lock
      Metal.should be_a_closure_tree.ordered(:sort_order).with_advisory_lock
    end

    it 'should not use advisory lock' do
      MenuItem.should be_a_closure_tree.without_advisory_lock
    end
  end

end

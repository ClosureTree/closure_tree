require 'spec_helper'

describe ClosureTree::Support do
  let(:sut) { Tag._ct }
  it 'passes through table names without prefix and suffix' do
    expected = 'some_random_table_name'
    sut.remove_prefix_and_suffix(expected).should == expected
  end
  it 'extracts through table name with prefix and suffix' do
    expected = 'some_random_table_name'
    tn = ActiveRecord::Base.table_name_prefix + expected + ActiveRecord::Base.table_name_suffix
    sut.remove_prefix_and_suffix(tn).should == expected
  end
end

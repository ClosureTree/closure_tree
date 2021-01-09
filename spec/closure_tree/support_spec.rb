require 'spec_helper'

RSpec.describe ClosureTree::Support do
  let(:sut) { Tag._ct }
  it 'passes through table names without prefix and suffix' do
    expected = 'some_random_table_name'
    expect(sut.remove_prefix_and_suffix(expected)).to eq(expected)
  end
  it 'extracts through table name with prefix and suffix' do
    expected = 'some_random_table_name'
    tn = ActiveRecord::Base.table_name_prefix + expected + ActiveRecord::Base.table_name_suffix
    expect(sut.remove_prefix_and_suffix(tn)).to eq(expected)
  end
end

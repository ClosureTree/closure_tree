require 'spec_helper'

RSpec.describe ClosureTree::Support do
  let(:model) { Tag }
  let(:options) { {} }
  let(:sut) { described_class.new(model, options) }

  it 'passes through table names without prefix and suffix' do
    expected = 'some_random_table_name'
    expect(sut.remove_prefix_and_suffix(expected)).to eq(expected)
  end

  it 'extracts through table name with prefix and suffix' do
    expected = 'some_random_table_name'
    tn = ActiveRecord::Base.table_name_prefix + expected + ActiveRecord::Base.table_name_suffix
    expect(sut.remove_prefix_and_suffix(tn)).to eq(expected)
  end

  [
    [true, 10, { timeout_seconds: 10 }],
    [true, nil, {}],
    [false, nil, {}]
  ].each do |with_lock, timeout, expected_options|
    context "when with_advisory_lock is #{with_lock} and timeout is #{timeout}" do
      let(:options) { { with_advisory_lock: with_lock, advisory_lock_timeout_seconds: timeout } }

      it "uses advisory lock with timeout options: #{expected_options}" do
        if with_lock
          expect(model).to receive(:with_advisory_lock!).with(anything, expected_options).and_yield
        else
          expect(model).not_to receive(:with_advisory_lock!)
        end

        expect { |b| sut.with_advisory_lock!(&b) }.to yield_control
      end
    end
  end
end
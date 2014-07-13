require 'spec_helper'

describe Metal do
  it "creates" do
    s = Metal.create(:value => 'System')
    s.reload
    expect(s).not_to be_new_record
  end
end

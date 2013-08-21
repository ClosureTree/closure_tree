require 'spec_helper'

describe Metal do
  it "creates" do
    s = Metal.create(:value => 'System')
    s.reload
    s.should_not be_new_record
  end
end

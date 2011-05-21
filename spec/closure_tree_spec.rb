require 'spec_helper'

describe ClosureTree do
  fixtures :tags
  describe "#roots" do
    it "returns only nodes with no parents" do
      Tag.roots
    end
  end
end

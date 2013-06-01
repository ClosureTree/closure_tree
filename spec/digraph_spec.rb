require 'spec_helper'

describe 'DOT rendering' do
  it 'should render for an empty scope' do
    Tag.to_dot_digraph(Tag.where("0=1")).should == "digraph G {\n}\n"
  end
  it 'should render for an empty scope' do
    Tag.find_or_create_by_path(%w(a b1 c1))
    Tag.find_or_create_by_path(%w(a b2 c2))
    Tag.find_or_create_by_path(%w(a b2 c3))
    dot = Tag.roots.first.to_dot_digraph
    dot.should == <<-DOT
digraph G {
  1 [label="a"]
  1 -> 2
  2 [label="b1"]
  1 -> 4
  4 [label="b2"]
  2 -> 3
  3 [label="c1"]
  4 -> 5
  5 [label="c2"]
  4 -> 6
  6 [label="c3"]
}
    DOT
  end
end

require 'spec_helper'

describe 'DOT rendering' do
  it 'should render for an empty scope' do
    Tag.to_dot_digraph(Tag.where("0=1")).should == "digraph G {\n}\n"
  end
  it 'should render for an empty scope' do
    Tag.find_or_create_by_path(%w(a b1 c1))
    Tag.find_or_create_by_path(%w(a b2 c2))
    Tag.find_or_create_by_path(%w(a b2 c3))
    a, b1, b2, c1, c2, c3 = %w(a b1 b2 c1 c2 c3).map { |ea| Tag.where(:name => ea).first.id }
    dot = Tag.roots.first.to_dot_digraph
    dot.should == <<-DOT
digraph G {
  #{a} [label="a"]
  #{a} -> #{b1}
  #{b1} [label="b1"]
  #{a} -> #{b2}
  #{b2} [label="b2"]
  #{b1} -> #{c1}
  #{c1} [label="c1"]
  #{b2} -> #{c2}
  #{c2} [label="c2"]
  #{b2} -> #{c3}
  #{c3} [label="c3"]
}
    DOT
  end
end

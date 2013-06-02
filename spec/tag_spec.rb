require 'spec_helper'
require 'tag_examples'
require 'tag_fixture_examples'

describe Tag do
  it_behaves_like 'Tag (without fixtures)'
  it_behaves_like 'Tag (with fixtures)'
end

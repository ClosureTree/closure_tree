require 'spec_helper'
require 'tag_examples'

describe UUIDTag do
  it_behaves_like "Tag (without fixtures)"
end unless ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 1

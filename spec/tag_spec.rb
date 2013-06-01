require 'spec_helper'
require 'tag_examples'
require 'tag_fixture_examples'


describe Tag do
  it_behaves_like 'Tag (without fixtures)'
  it_behaves_like 'Tag (with fixtures)'
end


if ActiveRecord::VERSION::MAJOR == 4
else
  describe Tag do
    it 'should not include ActiveModel::ForbiddenAttributesProtection' do
      if defined?(ActiveModel::ForbiddenAttributesProtection)
        Tag.ancestors.should_not include(ActiveModel::ForbiddenAttributesProtection)
      end
    end
    it_behaves_like 'Tag (without fixtures)'
    it_behaves_like 'Tag (with fixtures)'
  end

  describe 'Tag with AR whitelisted attributes enabled' do
    before(:all) do
      ActiveRecord::Base.attr_accessible(nil) # turn on whitelisted attributes
      ActiveRecord::Base.descendants.each { |ea| ea.reset_column_information }
    end
    it 'should not include ActiveModel::ForbiddenAttributesProtection' do
      if defined?(ActiveModel::ForbiddenAttributesProtection)
        Tag.ancestors.should_not include(ActiveModel::ForbiddenAttributesProtection)
      end
    end
    it_behaves_like 'Tag (without fixtures)'
    it_behaves_like 'Tag (with fixtures)'
  end

  describe StrongTag do
    it_behaves_like 'Tag (without fixtures)'
    it_behaves_like 'Tag (with fixtures)'
  end
end

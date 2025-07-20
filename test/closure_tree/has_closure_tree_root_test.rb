# frozen_string_literal: true

require 'test_helper'

class HasClosureTreeRootTest < ActiveSupport::TestCase
  setup do
    ENV['FLOCK_DIR'] = Dir.mktmpdir
  end

  teardown do
    FileUtils.remove_entry_secure ENV.fetch('FLOCK_DIR', nil)
  end
  def create_tree(group)
    @ct1 = ContractType.create!(name: 'Type1')
    @ct2 = ContractType.create!(name: 'Type2')
    @user1 = User.create!(email: '1@example.com', group_id: group.id)
    @user2 = User.create!(email: '2@example.com', group_id: group.id)
    @user3 = User.create!(email: '3@example.com', group_id: group.id)
    @user4 = User.create!(email: '4@example.com', group_id: group.id)
    @user5 = User.create!(email: '5@example.com', group_id: group.id)
    @user6 = User.create!(email: '6@example.com', group_id: group.id)

    # The tree (contract types in parens)
    #
    #                   U1(1)
    #                  /    \
    #              U2(1)   U3(1&2)
    #             /        /     \
    #         U4(2)      U5(1)   U6(2)

    @user1.children << @user2
    @user1.children << @user3
    @user2.children << @user4
    @user3.children << @user5
    @user3.children << @user6

    @user1.contracts.create!(title: 'Contract 1', contract_type: @ct1)
    @user2.contracts.create!(title: 'Contract 2', contract_type: @ct1)
    @user3.contracts.create!(title: 'Contract 3', contract_type: @ct1)
    @user3.contracts.create!(title: 'Contract 4', contract_type: @ct2)
    @user4.contracts.create!(title: 'Contract 5', contract_type: @ct2)
    @user5.contracts.create!(title: 'Contract 6', contract_type: @ct1)
    @user6.contracts.create!(title: 'Contract 7', contract_type: @ct2)
  end

  test 'loads all nodes in a constant number of queries' do
    group = Group.create!(name: 'TheGrouping')
    create_tree(group)
    reloaded_group = group.reload
    exceed_query_limit(2) do
      root = reloaded_group.root_user_including_tree
      assert_equal '2@example.com', root.children[0].email
      assert_equal '3@example.com', root.children[0].parent.children[1].email
    end
  end

  test 'loads all nodes plus single association in a constant number of queries' do
    group = Group.create!(name: 'TheGrouping')
    create_tree(group)
    reloaded_group = group.reload
    exceed_query_limit(3) do
      root = reloaded_group.root_user_including_tree(:contracts)
      assert_equal '2@example.com', root.children[0].email
      assert_equal '3@example.com', root.children[0].parent.children[1].email
      assert_equal 'Contract 7',
                   root.children[0].children[0].contracts[0].user.parent.parent.children[1].children[1].contracts[0].title
    end
  end

  test 'loads all nodes and associations in a constant number of queries' do
    group = Group.create!(name: 'TheGrouping')
    create_tree(group)
    reloaded_group = group.reload
    exceed_query_limit(4) do
      root = reloaded_group.root_user_including_tree(contracts: :contract_type)
      assert_equal '2@example.com', root.children[0].email
      assert_equal '3@example.com', root.children[0].parent.children[1].email
      assert_equal %w[Type1 Type2], root.children[1].contracts.map(&:contract_type).map(&:name)
      assert_equal 'Type1', root.children[1].children[0].contracts[0].contract_type.name
      assert_equal 'Type2',
                   root.children[0].children[0].contracts[0].user.parent.parent.children[1].children[1].contracts[0].contract_type.name
    end
  end
end

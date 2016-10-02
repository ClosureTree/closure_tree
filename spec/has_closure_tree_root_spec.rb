require "spec_helper"

describe "has_closure_tree_root" do
  let!(:ct1) { ContractType.create!(name: "Type1") }
  let!(:ct2) { ContractType.create!(name: "Type2") }
  let!(:user1) { User.create!(email: "1@example.com", group_id: group.id) }
  let!(:user2) { User.create!(email: "2@example.com", group_id: group.id) }
  let!(:user3) { User.create!(email: "3@example.com", group_id: group.id) }
  let!(:user4) { User.create!(email: "4@example.com", group_id: group.id) }
  let!(:user5) { User.create!(email: "5@example.com", group_id: group.id) }
  let!(:user6) { User.create!(email: "6@example.com", group_id: group.id) }

  before do
    # The tree (contract types in parens)
    #
    #                    U1(1)
    #                  /    \
    #              U2(1)   U3(1&2)
    #             /        /     \
    #         U4(2)      U5(1)   U6(2)

    user1.children << user2
    user1.children << user3
    user2.children << user4
    user3.children << user5
    user3.children << user6

    user1.contracts.create!(contract_type: ct1)
    user2.contracts.create!(contract_type: ct1)
    user3.contracts.create!(contract_type: ct1)
    user3.contracts.create!(contract_type: ct2)
    user4.contracts.create!(contract_type: ct2)
    user5.contracts.create!(contract_type: ct1)
    user6.contracts.create!(contract_type: ct2)
  end

  context "with basic config" do
    let!(:group) { Group.create!(name: "TheGroup") }

    before do
      group = Group.first # Ensure we're starting fresh
    end

    it "loads all nodes and associations in a constant number of queries" do
      expect do
        root = group.root_user_including_tree(contracts: :contract_type)
        expect(root.children[0].email).to eq "2@example.com"
        expect(root.children[0].parent.children[1].email).to eq "3@example.com"
        expect(root.children[1].contracts.map(&:contract_type).map(&:name)).to eq %w(Type1 Type2)
        expect(root.children[1].children[0].contracts[0].contract_type.name).to eq "Type1"
        expect(root.children[0].children[0].contracts[0].user.
          parent.parent.children[1].children[1].contracts[0].contract_type.name).to eq "Type2"
      end.to_not exceed_query_limit(4) # Without this feature, this is 15, and scales with number of nodes.
    end

    it "works if eager load association map is not given" do
      expect do
        root = group.root_user_including_tree
        expect(root.children[0].email).to eq "2@example.com"
        expect(root.children[0].parent.children[1].children[0].email).to eq "5@example.com"
      end.to_not exceed_query_limit(2)
    end

    context "with no tree root" do
      let(:group2) { Group.create!(name: "OtherGroup") }

      it "should return nil" do
        expect(group2.root_user_including_tree(contracts: :contract_type)).to be_nil
      end
    end

    context "with multiple tree roots" do
      let!(:other_root) { User.create!(email: "10@example.com", group_id: group.id) }

      it "should error" do
        expect do
          root = group.root_user_including_tree(contracts: :contract_type)
        end.to raise_error(ClosureTree::MultipleRootError)
      end
    end
  end

  context "with explicit class_name and foreign_key" do
    let(:group) { Grouping.create!(name: "TheGrouping") }

    it "should still work" do
      root = group.root_person_including_tree(contracts: :contract_type)
      expect(root.children[0].email).to eq "2@example.com"
    end
  end

  context "with bad class_name" do
    let(:group) { UserSet.create!(name: "TheUserSet") }

    it "should error" do
      expect do
        root = group.root_user_including_tree(contracts: :contract_type)
      end.to raise_error(NameError)
    end
  end

  context "with bad foreign_key" do
    let(:group) { Team.create!(name: "TheTeam") }

    it "should error" do
      expect do
        root = group.root_user_including_tree(contracts: :contract_type)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end

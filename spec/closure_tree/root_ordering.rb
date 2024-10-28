# frozen_string_literal: true

require "spec_helper"

describe Block do
  describe "correct root order_value" do
    let!(:group) { Group.create!(name: "TheGroup") }
    let!(:user1) { User.create!(email: "1@example.com", group_id: group.id) }
    let!(:user2) { User.create!(email: "2@example.com", group_id: group.id) }
    let!(:block1) { Block.create!(name: "1block", user_id: user1.id) }
    let!(:block2) { Block.create!(name: "2block", user_id: user2.id) }
    let!(:block3) { Block.create!(name: "3block", user_id: user1.id) }
    let!(:block4) { Block.create!(name: "4block", user_id: user2.id) }
    let!(:block5) { Block.create!(name: "5block", user_id: user1.id) }
    let!(:block6) { Block.create!(name: "6block", user_id: user2.id) }

    it "should set order_value on roots" do
      assert_equal block1.self_and_siblings.pluck(:sort_order), [1,2,3]
      assert_equal block2.self_and_siblings.pluck(:sort_order), [1,2,3]
    end
  end
end

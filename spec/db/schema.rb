# encoding: UTF-8

ActiveRecord::Schema.define(:version => 0) do

  create_table "tags" do |t|
    t.string "name"
    t.string "title"
    t.integer "parent_id"
    t.integer "sort_order"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_foreign_key(:tags, :tags, :column => 'parent_id')

  create_table "tag_hierarchies", :id => false do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  add_foreign_key(:tag_hierarchies, :tags, :column => 'ancestor_id')
  add_foreign_key(:tag_hierarchies, :tags, :column => 'descendant_id')

  create_table "uuid_tags", :id => false do |t|
    t.string "uuid", :unique => true
    t.string "name"
    t.string "title"
    t.string "parent_uuid"
    t.integer "sort_order"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "uuid_tag_hierarchies", :id => false do |t|
    t.string "ancestor_id", :null => false
    t.string "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  create_table "destroyed_tags" do |t|
    t.string "name"
  end

  add_index "tag_hierarchies", [:ancestor_id, :descendant_id, :generations], :unique => true, :name => "tag_anc_desc_idx"
  add_index "tag_hierarchies", [:descendant_id], :name => "tag_desc_idx"

  create_table "users" do |t|
    t.string "email"
    t.integer "referrer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_foreign_key(:users, :users, :column => 'referrer_id')

  create_table "contracts" do |t|
    t.integer "user_id", :null => false
  end

  create_table "referral_hierarchies", :id => false do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  add_index "referral_hierarchies", [:ancestor_id, :descendant_id, :generations], :unique => true, :name => "ref_anc_desc_idx"
  add_index "referral_hierarchies", [:descendant_id], :name => "ref_desc_idx"

  create_table "labels" do |t|
    t.string "name"
    t.string "type"
    t.integer "column_whereby_ordering_is_inferred"
    t.integer "mother_id"
  end

  add_foreign_key(:labels, :labels, :column => 'mother_id')

  create_table "label_hierarchies", :id => false do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  add_index "label_hierarchies", [:ancestor_id, :descendant_id, :generations], :unique => true, :name => "lh_anc_desc_idx"
  add_index "label_hierarchies", [:descendant_id], :name => "lh_desc_idx"

  create_table "cuisine_types" do |t|
    t.string "name"
    t.integer "parent_id"
  end

  create_table "cuisine_type_hierarchies", :id => false do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  create_table "namespace_types" do |t|
    t.string "name"
    t.integer "parent_id"
  end

  create_table "namespace_type_hierarchies", :id => false do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  create_table "metal" do |t|
    t.integer "parent_id"
    t.string "metal_type"
    t.string "value"
    t.integer "sort_order"
  end

  add_foreign_key(:metal, :metal, :column => 'parent_id')

  create_table "metal_hierarchies", :id => false do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  add_foreign_key(:metal_hierarchies, :metal, :column => 'ancestor_id')
  add_foreign_key(:metal_hierarchies, :metal, :column => 'descendant_id')

  create_table 'menu_items' do |t|
    t.string 'name'
    t.integer 'parent_id'
    t.integer 'child_count', null: false, default: 0
    t.timestamps
  end

  add_foreign_key(:menu_items, :menu_items, :column => 'parent_id')

  create_table 'menu_item_hierarchies', :id => false do |t|
    t.integer 'ancestor_id', :null => false
    t.integer 'descendant_id', :null => false
    t.integer 'generations', :null => false
  end

  add_foreign_key(:menu_item_hierarchies, :menu_items, :column => 'ancestor_id')
  add_foreign_key(:menu_item_hierarchies, :menu_items, :column => 'descendant_id')

end

# encoding: UTF-8
ActiveRecord::Schema.define(:version => 0) do

  create_table "tags", :force => true do |t|
    t.string   "name"
    t.string   "title"
    t.integer  "parent_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id",   :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations",   :null => false
  end

  create_table "destroyed_tags", :force => true do |t|
    t.string   "name"
  end

  add_index :tag_hierarchies, [:ancestor_id, :descendant_id], :unique => true
  add_index :tag_hierarchies, [:descendant_id]

  create_table "users", :force => true do |t|
    t.string   "email"
    t.integer  "referrer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "referral_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id",   :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations",   :null => false
  end

  add_index :referral_hierarchies, [:ancestor_id, :descendant_id], :unique => true
  add_index :referral_hierarchies, [:descendant_id]

  create_table "labels", :force => true do |t|
    t.string   "name"
    t.string   "type"
    t.integer  "parent_id"
  end

  create_table "label_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id",   :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations",   :null => false
  end

  add_index :label_hierarchies, [:ancestor_id, :descendant_id], :unique => true
  add_index :label_hierarchies, [:descendant_id]

end

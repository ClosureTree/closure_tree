# encoding: UTF-8
class ActiveRecord::ConnectionAdapters::AbstractAdapter
  def force_add_index(table_name, columns, options = {})
    begin
      remove_index!(table_name, options[:name])
    rescue ActiveRecord::StatementInvalid, ArgumentError
    end
    add_index table_name, columns, options
  end
end

ActiveRecord::Schema.define(:version => 0) do

  create_table "tags", :force => true do |t|
    t.string "name"
    t.string "title"
    t.integer "parent_id"
    t.integer "sort_order"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  create_table "tags_uuid", :id => false, :force => true do |t|
    t.string "id", :unique => true
    t.string "name"
    t.string "title"
    t.string "parent_id"
    t.integer "sort_order"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_hierarchies_uuid", :id => false, :force => true do |t|
    t.string "ancestor_id", :null => false
    t.string "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  create_table "destroyed_tags", :force => true do |t|
    t.string "name"
  end

  force_add_index "tag_hierarchies", [:ancestor_id, :descendant_id], :unique => true, :name => "tag_anc_desc_idx"
  force_add_index "tag_hierarchies", [:descendant_id], :name => "tag_desc_idx"

  create_table "users", :force => true do |t|
    t.string "email"
    t.integer "referrer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "contracts", :force => true do |t|
    t.integer "user_id", :null => false
  end

  create_table "referral_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  force_add_index "referral_hierarchies", [:ancestor_id, :descendant_id], :unique => true, :name => "ref_anc_desc_idx"
  force_add_index "referral_hierarchies", [:descendant_id], :name => "ref_desc_idx"

  create_table "labels", :force => true do |t|
    t.string "name"
    t.string "type"
    t.integer "sort_order"
    t.integer "mother_id"
  end

  create_table "label_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  force_add_index "label_hierarchies", [:ancestor_id, :descendant_id], :unique => true, :name => "lh_anc_desc_idx"
  force_add_index "label_hierarchies", [:descendant_id], :name => "lh_desc_idx"

  create_table "cuisine_types", :force => true do |t|
    t.string "name"
    t.integer "parent_id"
  end

  create_table "cuisine_type_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end

  create_table "namespace_types", :force => true do |t|
    t.string "name"
    t.integer "parent_id"
  end

  create_table "namespace_type_hierarchies", :id => false, :force => true do |t|
    t.integer "ancestor_id", :null => false
    t.integer "descendant_id", :null => false
    t.integer "generations", :null => false
  end
end

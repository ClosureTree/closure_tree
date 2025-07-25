# frozen_string_literal: true

ActiveRecord::Schema.define(version: 1) do
  create_table 'tags' do |t|
    t.string 'name'
    t.string 'title'
    t.references 'parent'
    t.integer 'sort_order'
    t.timestamps null: false
  end

  create_table 'tag_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table 'uuid_tags', id: false do |t|
    t.string 'uuid', primary_key: true
    t.string 'name'
    t.string 'title'
    t.string 'parent_uuid'
    t.integer 'sort_order'
    t.timestamps null: false
  end

  create_table 'uuid_tag_hierarchies', id: false do |t|
    t.string 'ancestor_id', null: false
    t.string 'descendant_id', null: false
    t.integer 'generations', null: false
  end

  create_table 'destroyed_tags' do |t|
    t.string 'name'
  end

  add_index 'tag_hierarchies', %i[ancestor_id descendant_id generations], unique: true,
                                                                          name: 'tag_anc_desc_idx'
  add_index 'tag_hierarchies', [:descendant_id], name: 'tag_desc_idx'

  create_table 'groups' do |t|
    t.string 'name', null: false
  end

  create_table 'groupings' do |t|
    t.string 'name', null: false
  end

  create_table 'user_sets' do |t|
    t.string 'name', null: false
  end

  create_table 'teams' do |t|
    t.string 'name', null: false
  end

  create_table 'users' do |t|
    t.string 'email'
    t.references 'referrer'
    t.integer 'group_id'
    t.timestamps null: false
  end

  create_table 'contracts' do |t|
    t.references 'user', null: false
    t.references 'contract_type'
    t.string 'title'
  end

  create_table 'contract_types' do |t|
    t.string 'name', null: false
  end

  create_table 'referral_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table 'labels' do |t|
    t.string 'name'
    t.string 'type'
    t.integer 'column_whereby_ordering_is_inferred'
    t.references 'mother'
  end

  create_table 'label_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table 'cuisine_types' do |t|
    t.string 'name'
    t.references 'parent'
  end

  create_table 'cuisine_type_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table 'namespace_types' do |t|
    t.string 'name'
    t.references 'parent'
  end

  create_table 'namespace_type_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table 'metal' do |t|
    t.references 'parent'
    t.string 'metal_type'
    t.string 'value'
    t.string 'description'
    t.integer 'sort_order'
  end

  create_table 'metal_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table 'menu_items' do |t|
    t.string 'name'
    t.references 'parent'
    t.timestamps null: false
  end

  create_table 'menu_item_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  add_index 'label_hierarchies', %i[ancestor_id descendant_id generations], unique: true,
                                                                            name: 'lh_anc_desc_idx'
  add_index 'label_hierarchies', [:descendant_id], name: 'lh_desc_idx'
  add_index 'referral_hierarchies', %i[ancestor_id descendant_id generations], unique: true,
                                                                               name: 'ref_anc_desc_idx'
  add_index 'referral_hierarchies', [:descendant_id], name: 'ref_desc_idx'

  add_foreign_key(:tags, :tags, column: 'parent_id', on_delete: :cascade)
  add_foreign_key(:users, :users, column: 'referrer_id', on_delete: :cascade)
  add_foreign_key(:labels, :labels, column: 'mother_id', on_delete: :cascade)
  add_foreign_key(:metal, :metal, column: 'parent_id', on_delete: :cascade)
  add_foreign_key(:menu_items, :menu_items, column: 'parent_id', on_delete: :cascade)
  add_foreign_key(:menu_item_hierarchies, :menu_items, column: 'ancestor_id', on_delete: :cascade)
  add_foreign_key(:menu_item_hierarchies, :menu_items, column: 'descendant_id', on_delete: :cascade)
  add_foreign_key(:tag_hierarchies, :tags, column: 'ancestor_id', on_delete: :cascade)
  add_foreign_key(:tag_hierarchies, :tags, column: 'descendant_id', on_delete: :cascade)

  # Multi-database test models
  create_table 'mysql_tags' do |t|
    t.string 'name'
    t.references 'parent'
    t.timestamps null: false
  end

  create_table 'mysql_tag_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  add_index 'mysql_tag_hierarchies', %i[ancestor_id descendant_id generations], unique: true,
                                                                                name: 'mysql_tag_anc_desc_idx'
  add_index 'mysql_tag_hierarchies', [:descendant_id], name: 'mysql_tag_desc_idx'

  create_table 'sqlite_tags' do |t|
    t.string 'name'
    t.references 'parent'
    t.timestamps null: false
  end

  create_table 'sqlite_tag_hierarchies', id: false do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  add_index 'sqlite_tag_hierarchies', %i[ancestor_id descendant_id generations], unique: true,
                                                                                 name: 'sqlite_tag_anc_desc_idx'
  add_index 'sqlite_tag_hierarchies', [:descendant_id], name: 'sqlite_tag_desc_idx'
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 1) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "adoptable_tag_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "adoptable_tag_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_adoptable_tag_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "adoptable_tag_desc_idx"
    t.index ["descendant_id"], name: "index_adoptable_tag_hierarchies_on_descendant_id"
  end

  create_table "adoptable_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_adoptable_tags_on_parent_id"
  end

  create_table "contract_types", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "contract_type_id"
    t.string "title"
    t.bigint "user_id", null: false
    t.index ["contract_type_id"], name: "index_contracts_on_contract_type_id"
    t.index ["user_id"], name: "index_contracts_on_user_id"
  end

  create_table "cuisine_type_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id"], name: "index_cuisine_type_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_cuisine_type_hierarchies_on_descendant_id"
  end

  create_table "cuisine_types", force: :cascade do |t|
    t.string "name"
    t.bigint "parent_id"
    t.index ["parent_id"], name: "index_cuisine_types_on_parent_id"
  end

  create_table "destroyed_tags", force: :cascade do |t|
    t.string "name"
  end

  create_table "groupings", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "label_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "lh_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_label_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_label_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "lh_desc_idx"
  end

  create_table "labels", force: :cascade do |t|
    t.integer "column_whereby_ordering_is_inferred"
    t.bigint "mother_id"
    t.string "name"
    t.string "type"
    t.index ["mother_id"], name: "index_labels_on_mother_id"
  end

  create_table "lite_tag_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "lite_tag_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_lite_tag_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_lite_tag_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "lite_tag_desc_idx"
  end

  create_table "lite_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_lite_tags_on_parent_id"
  end

  create_table "memory_adoptable_tag_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "memory_adoptable_tag_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_memory_adoptable_tag_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_memory_adoptable_tag_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "memory_adoptable_tag_desc_idx"
  end

  create_table "memory_adoptable_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_memory_adoptable_tags_on_parent_id"
  end

  create_table "menu_item_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id"], name: "index_menu_item_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_menu_item_hierarchies_on_descendant_id"
  end

  create_table "menu_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_menu_items_on_parent_id"
  end

  create_table "metal", force: :cascade do |t|
    t.string "description"
    t.string "metal_type"
    t.bigint "parent_id"
    t.integer "sort_order"
    t.string "value"
    t.index ["parent_id"], name: "index_metal_on_parent_id"
  end

  create_table "metal_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id"], name: "index_metal_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_metal_hierarchies_on_descendant_id"
  end

  create_table "namespace_type_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id"], name: "index_namespace_type_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_namespace_type_hierarchies_on_descendant_id"
  end

  create_table "namespace_types", force: :cascade do |t|
    t.string "name"
    t.bigint "parent_id"
    t.index ["parent_id"], name: "index_namespace_types_on_parent_id"
  end

  create_table "referral_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "ref_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_referral_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_referral_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "ref_desc_idx"
  end

  create_table "scoped_item_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "scoped_item_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_scoped_item_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_scoped_item_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "scoped_item_desc_idx"
  end

  create_table "scoped_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_id"
    t.string "name"
    t.bigint "parent_id"
    t.integer "sort_order"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["parent_id"], name: "index_scoped_items_on_parent_id"
  end

  create_table "secondary_adoptable_tag_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "secondary_adoptable_tag_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_secondary_adoptable_tag_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_secondary_adoptable_tag_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "secondary_adoptable_tag_desc_idx"
  end

  create_table "secondary_adoptable_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_secondary_adoptable_tags_on_parent_id"
  end

  create_table "secondary_tag_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "secondary_tag_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_secondary_tag_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_secondary_tag_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "secondary_tag_desc_idx"
  end

  create_table "secondary_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_secondary_tags_on_parent_id"
  end

  create_table "tag_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "tag_anc_desc_idx", unique: true
    t.index ["ancestor_id"], name: "index_tag_hierarchies_on_ancestor_id"
    t.index ["descendant_id"], name: "index_tag_hierarchies_on_descendant_id"
    t.index ["descendant_id"], name: "tag_desc_idx"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "parent_id"
    t.integer "sort_order"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_tags_on_parent_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "user_sets", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "group_id"
    t.bigint "referrer_id"
    t.datetime "updated_at", null: false
    t.index ["referrer_id"], name: "index_users_on_referrer_id"
  end

  create_table "uuid_tag_hierarchies", id: false, force: :cascade do |t|
    t.string "ancestor_id", null: false
    t.string "descendant_id", null: false
    t.integer "generations", null: false
  end

  create_table "uuid_tags", primary_key: "uuid", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "parent_uuid"
    t.integer "sort_order"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "labels", "labels", column: "mother_id", on_delete: :cascade
  add_foreign_key "menu_item_hierarchies", "menu_items", column: "ancestor_id", on_delete: :cascade
  add_foreign_key "menu_item_hierarchies", "menu_items", column: "descendant_id", on_delete: :cascade
  add_foreign_key "menu_items", "menu_items", column: "parent_id", on_delete: :cascade
  add_foreign_key "metal", "metal", column: "parent_id", on_delete: :cascade
  add_foreign_key "tag_hierarchies", "tags", column: "ancestor_id", on_delete: :cascade
  add_foreign_key "tag_hierarchies", "tags", column: "descendant_id", on_delete: :cascade
  add_foreign_key "tags", "tags", column: "parent_id", on_delete: :cascade
  add_foreign_key "users", "users", column: "referrer_id", on_delete: :cascade
end

# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do
  create_table 'mysql_tags', force: true do |t|
    t.string   'name'
    t.integer  'parent_id'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  create_table 'mysql_tag_hierarchies', id: false, force: true do |t|
    t.integer  'ancestor_id', null: false
    t.integer  'descendant_id', null: false
    t.integer  'generations', null: false
  end

  add_index 'mysql_tag_hierarchies', %i[ancestor_id descendant_id generations], unique: true,
                                                                                name: 'mysql_tag_anc_des_idx'
  add_index 'mysql_tag_hierarchies', [:descendant_id], name: 'mysql_tag_desc_idx'
end

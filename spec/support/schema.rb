# frozen_string_literal: true

require_relative 'models'
ApplicationRecord.establish_connection
if sqlite?
  ActiveRecord::Tasks::DatabaseTasks.drop(:primary, 'test')
  ActiveRecord::Tasks::DatabaseTasks.create(:primary, 'test')
  ActiveRecord::Tasks::DatabaseTasks.drop(:secondary, 'test')
  ActiveRecord::Tasks::DatabaseTasks.create(:secondary, 'test')
else
  ActiveRecord::Tasks::DatabaseTasks.drop(:primary)
  ActiveRecord::Tasks::DatabaseTasks.create(:primary)
  ActiveRecord::Tasks::DatabaseTasks.drop(:secondary)
  ActiveRecord::Tasks::DatabaseTasks.create(:secondary)
end

ActiveRecord::Schema.define(version: 0) do
  connection.create_table Tag.table_name, force: :cascade do |t|
    t.string 'name'
    t.string 'title'
    t.references 'parent'
    t.integer 'sort_order'
    t.timestamps null: false
  end

  create_table Tag.hierarchy_class.table_name, id: false, force: :cascade do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  add_index Tag.hierarchy_class.table_name, %i[ancestor_id descendant_id generations], unique: true,
                                                                                       name: 'tag_anc_desc_idx'
  add_index Tag.hierarchy_class.table_name, [:descendant_id], name: 'tag_desc_idx'

  create_table UUIDTag.table_name, id: false, force: :cascade do |t|
    t.string 'uuid', primary_key: true
    t.string 'name'
    t.string 'title'
    t.string 'parent_uuid'
    t.integer 'sort_order'
    t.timestamps null: false
  end

  create_table UUIDTag.hierarchy_class.table_name, id: false, force: :cascade do |t|
    t.string 'ancestor_id', null: false
    t.string 'descendant_id', null: false
    t.integer 'generations', null: false
  end

  create_table DestroyedTag.table_name, force: :cascade do |t|
    t.string 'name'
  end

  create_table Group.table_name, force: :cascade do |t|
    t.string 'name', null: false
  end

  create_table Grouping.table_name, force: :cascade do |t|
    t.string 'name', null: false
  end

  create_table UserSet.table_name, force: :cascade do |t|
    t.string 'name', null: false
  end

  create_table Team.table_name, force: :cascade do |t|
    t.string 'name', null: false
  end

  create_table User.table_name, force: :cascade do |t|
    t.string 'email'
    t.references 'referrer'
    t.integer 'group_id'
    t.timestamps null: false
  end

  create_table User.hierarchy_class.table_name, id: false, force: :cascade do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  add_index User.hierarchy_class.table_name, %i[ancestor_id descendant_id generations], unique: true,
                                                                                        name: 'ref_anc_desc_idx'
  add_index User.hierarchy_class.table_name, [:descendant_id], name: 'ref_desc_idx'

  create_table Contract.table_name, force: :cascade do |t|
    t.references 'user', null: false
    t.references 'contract_type'
    t.string 'title'
  end

  create_table ContractType.table_name, force: :cascade do |t|
    t.string 'name', null: false
  end

  create_table Label.table_name, force: :cascade do |t|
    t.string 'name'
    t.string 'type'
    t.integer 'column_whereby_ordering_is_inferred'
    t.references 'mother'
  end

  create_table Label.hierarchy_class.table_name, id: false, force: :cascade do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  add_index Label.hierarchy_class.table_name, %i[ancestor_id descendant_id generations], unique: true,
                                                                                         name: 'lh_anc_desc_idx'
  add_index Label.hierarchy_class.table_name, [:descendant_id], name: 'lh_desc_idx'

  create_table CuisineType.table_name, force: :cascade do |t|
    t.string 'name'
    t.references 'parent'
  end

  create_table CuisineType.hierarchy_class.table_name, id: false, force: :cascade do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table Namespace::Type.table_name, force: :cascade do |t|
    t.string 'name'
    t.references 'parent'
  end

  create_table Namespace::Type.hierarchy_class.table_name, id: false, force: :cascade do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  create_table Metal.table_name, force: :cascade do |t|
    t.references 'parent'
    t.string 'metal_type'
    t.string 'value'
    t.string 'description'
    t.integer 'sort_order'
  end

  create_table Metal.hierarchy_class.table_name, id: false, force: :cascade do |t|
    t.references 'ancestor', null: false
    t.references 'descendant', null: false
    t.integer 'generations', null: false
  end

  add_foreign_key(Tag.table_name, Tag.table_name, column: 'parent_id', on_delete: :cascade)
  add_foreign_key(User.table_name, User.table_name, column: 'referrer_id', on_delete: :cascade)
  add_foreign_key(Label.table_name, Label.table_name, column: 'mother_id', on_delete: :cascade)
  add_foreign_key(Metal.table_name, Metal.table_name, column: 'parent_id', on_delete: :cascade)
  add_foreign_key(Tag.hierarchy_class.table_name, Tag.table_name, column: 'ancestor_id', on_delete: :cascade)
  add_foreign_key(Tag.hierarchy_class.table_name, Tag.table_name, column: 'descendant_id', on_delete: :cascade)
end

SecondDatabaseRecord.establish_connection
SecondDatabaseRecord.connection_pool.with_connection do |connection|
  ActiveRecord::Schema.define(version: 0) do
    connection.create_table MenuItem.table_name, force: :cascade do |t|
      t.string 'name'
      t.references 'parent'
      t.timestamps null: false
    end

    connection.create_table MenuItem.hierarchy_class.table_name, id: false, force: :cascade do |t|
      t.references 'ancestor', null: false
      t.references 'descendant', null: false
      t.integer 'generations', null: false
    end
    connection.add_foreign_key(MenuItem.table_name, MenuItem.table_name, column: 'parent_id', on_delete: :cascade)
    connection.add_foreign_key(MenuItem.hierarchy_class.table_name, MenuItem.table_name, column: 'ancestor_id',
                                                                                         on_delete: :cascade)
    connection.add_foreign_key(MenuItem.hierarchy_class.table_name, MenuItem.table_name, column: 'descendant_id',
                                                                                         on_delete: :cascade)
  end
end

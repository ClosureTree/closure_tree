ActiveRecord::Schema.define(:version => 0) do
  create_table :tags, :force => true do |t|
    t.column :name, :string
    t.column :parent_id, :integer
  end
end

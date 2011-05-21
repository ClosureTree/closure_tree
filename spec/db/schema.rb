ActiveRecord::Schema.define(:version => 0) do
  create_table :tags, :force => true do |t|
    t.column :parent_id, :integer
    t.column :name, :string
  end
end

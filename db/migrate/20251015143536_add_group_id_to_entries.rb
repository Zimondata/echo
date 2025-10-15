class AddGroupIdToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :group_id, :string
    add_index :entries, :group_id
    add_column :entries, :parent_entry_id, :integer
    add_index :entries, :parent_entry_id
  end
end

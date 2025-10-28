class AddLastEntryContextToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_entry_ids, :json
    add_column :users, :last_entry_timestamp, :datetime
  end
end

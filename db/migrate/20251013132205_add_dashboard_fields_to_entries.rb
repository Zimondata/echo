class AddDashboardFieldsToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :category, :string, default: 'inbox'
    add_column :entries, :dashboard_status, :string, default: 'new'
    add_column :entries, :tags, :text
    add_column :entries, :insights, :jsonb, default: {}
    add_column :entries, :processed_at, :datetime

    # Add indexes for efficient querying
    add_index :entries, :category
    add_index :entries, :dashboard_status
    add_index :entries, :processed_at
  end
end

class AddIdeaFieldsToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :idea_category, :string
    add_column :entries, :idea_status, :string, default: 'new'
    add_column :entries, :idea_priority, :integer, default: 5
    add_column :entries, :research_data, :json
    add_column :entries, :quest_generated, :boolean, default: false
    
    # Add indexes for performance
    add_index :entries, :idea_category
    add_index :entries, :idea_status
    add_index :entries, :idea_priority
  end
end

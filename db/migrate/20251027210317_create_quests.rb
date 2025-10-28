class CreateQuests < ActiveRecord::Migration[8.0]
  def change
    create_table :quests do |t|
      t.references :entry, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, default: 'active'
      t.integer :priority, default: 5
      t.datetime :due_date
      t.json :steps, default: []
      t.integer :completion_rate, default: 0
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    # Add indexes
    add_index :quests, :status
    add_index :quests, :priority
    add_index :quests, :due_date
    add_index :quests, [:user_id, :status]
  end
end

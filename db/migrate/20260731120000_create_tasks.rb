class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :next_action
      t.string :owner_type, null: false, default: 'user'
      t.string :status, null: false, default: 'inbox'
      t.integer :estimate_minutes
      t.date :due_on
      t.datetime :deleted_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :tasks, [ :user_id, :status ]
    add_index :tasks, :deleted_at
    add_index :tasks, :due_on
  end
end

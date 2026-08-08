class CreateProjectsAndAssignTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.datetime :archived_at
      t.integer :position, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :projects, %i[user_id archived_at position]
    add_reference :tasks, :project, null: true, foreign_key: { on_delete: :nullify }
    add_index :tasks, %i[user_id project_id]
  end
end

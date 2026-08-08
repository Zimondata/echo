class CreateTaskSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :task_steps do |t|
      t.references :task, null: false, foreign_key: true
      t.string :text, null: false
      t.integer :position, null: false
      t.datetime :completed_at
      t.timestamps
    end

    add_index :task_steps, %i[task_id position]
  end
end

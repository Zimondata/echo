class CreateTimeBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :time_blocks do |t|
      t.references :task, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :source, null: false, default: "manual"
      t.boolean :locked, null: false, default: false
      t.string :previous_task_status, null: false
      t.datetime :cancelled_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :time_blocks, :starts_at
    add_index :time_blocks, %i[task_id cancelled_at]
    add_index :time_blocks, :task_id, unique: true, where: "cancelled_at IS NULL", name: "index_time_blocks_on_active_task"
    add_check_constraint :time_blocks, "ends_at > starts_at", name: "time_blocks_positive_interval"
    add_check_constraint :time_blocks, "source IN ('manual')", name: "time_blocks_source_allowed"
    add_check_constraint :time_blocks, "previous_task_status IN ('inbox', 'next')", name: "time_blocks_previous_status_allowed"
  end
end

class AddLifecycleFieldsToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :completed_at, :datetime
    add_column :tasks, :dropped_at, :datetime
    add_column :tasks, :drop_reason, :string, limit: 500
  end
end

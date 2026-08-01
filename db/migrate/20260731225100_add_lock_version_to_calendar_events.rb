class AddLockVersionToCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_events, :lock_version, :integer, null: false, default: 0
  end
end

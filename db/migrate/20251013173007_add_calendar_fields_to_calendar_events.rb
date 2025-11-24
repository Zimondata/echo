class AddCalendarFieldsToCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_events, :all_day, :boolean, default: false
    add_column :calendar_events, :done, :boolean, default: false
    add_column :calendar_events, :priority, :string, default: 'medium'
    add_column :calendar_events, :color, :string
    add_column :calendar_events, :tags, :json, default: []
    add_column :calendar_events, :reminder_minutes, :integer
    add_column :calendar_events, :reminder_sent, :boolean, default: false
    add_column :calendar_events, :deleted_at, :datetime
    
    add_index :calendar_events, :deleted_at
    add_index :calendar_events, :done
    add_index :calendar_events, :all_day
  end
end

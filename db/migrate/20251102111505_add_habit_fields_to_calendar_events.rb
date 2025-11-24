class AddHabitFieldsToCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_events, :is_habit, :boolean, default: false
    add_column :calendar_events, :habit_streak, :integer, default: 0
    add_column :calendar_events, :last_completed_at, :datetime
    add_column :calendar_events, :recurrence_pattern, :string

    add_index :calendar_events, :is_habit
    add_index :calendar_events, :recurrence_pattern
  end
end

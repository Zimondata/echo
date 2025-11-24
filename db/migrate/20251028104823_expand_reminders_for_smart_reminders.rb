class ExpandRemindersForSmartReminders < ActiveRecord::Migration[8.0]
  def change
    # Add new fields for smart reminders
    add_column :reminders, :smart_type, :string # 'idea', 'pattern', 'goal', 'context', 'suggestion'
    add_column :reminders, :smart_trigger, :string # What triggered this: 'idea_aging', 'pattern_break', 'goal_check'
    add_column :reminders, :related_entry_ids, :json, default: [] # Array of related entry IDs
    add_column :reminders, :confidence_score, :integer # 0-100, how confident AI is about this reminder
    add_column :reminders, :ai_context, :json, default: {} # Additional context for AI
    add_column :reminders, :action_buttons, :json, default: [] # Interactive buttons for Telegram
    add_column :reminders, :priority, :string, default: 'medium' # 'high', 'medium', 'low'
    add_column :reminders, :recurrence_rule, :string # For recurring reminders: 'daily', 'weekly', 'monthly', cron-like
    add_column :reminders, :user_feedback, :string # User response: 'helpful', 'not_helpful', 'snoozed'

    # Add indexes for performance
    add_index :reminders, :smart_type
    add_index :reminders, :priority
    add_index :reminders, :confidence_score
  end
end

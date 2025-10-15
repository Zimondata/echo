class RemoveGoogleFieldsFromCalendarEventsAndUsers < ActiveRecord::Migration[8.0]
  def change
    # Remove Google-specific fields from calendar_events
    remove_column :calendar_events, :google_event_id, :string
    
    # Remove Google-specific fields from users
    remove_column :users, :google_refresh_token, :text
    remove_column :users, :google_access_token, :text
    remove_column :users, :google_token_expires_at, :datetime
  end
end

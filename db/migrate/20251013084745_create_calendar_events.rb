class CreateCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_events do |t|
      t.references :entry, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :google_event_id
      t.string :title, null: false
      t.text :description
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.string :event_type, default: "plan" # plan, note, reminder
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :calendar_events, :google_event_id, unique: true
    add_index :calendar_events, :start_time
  end
end

class CreateActivityEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :activity_type, null: false  # running, cycling, strength, swimming, etc.
      t.integer :duration_minutes           # Total duration in minutes
      t.decimal :distance_km, precision: 8, scale: 3  # Distance in kilometers (up to 99999.999)
      t.integer :calories_burned           # Calories burned during activity
      t.integer :average_heart_rate        # Average heart rate (bpm)
      t.integer :max_heart_rate            # Maximum heart rate (bpm)
      t.string :average_pace               # Average pace (e.g., "5:30/km")
      t.datetime :activity_date, null: false  # When the activity took place
      t.text :notes                        # User notes or AI analysis
      t.jsonb :garmin_data, default: {}    # Raw Garmin data from screenshot analysis
      t.string :screenshot_url             # URL to stored screenshot
      t.string :status, default: 'active'  # active, archived, deleted
      t.integer :effort_level             # 1-10 subjective effort level
      t.text :ai_analysis                 # AI-generated analysis and insights

      t.timestamps
    end

    # Add indexes for better query performance
    add_index :activity_entries, [:user_id, :activity_date]
    add_index :activity_entries, [:user_id, :activity_type]
    add_index :activity_entries, [:user_id, :status]
    add_index :activity_entries, :activity_date
  end
end

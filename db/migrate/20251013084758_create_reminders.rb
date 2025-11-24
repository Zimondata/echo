class CreateReminders < ActiveRecord::Migration[8.0]
  def change
    create_table :reminders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, foreign_key: true
      t.string :reminder_type, null: false # one_time, recurring, smart
      t.datetime :remind_at, null: false
      t.string :status, default: "pending" # pending, sent, snoozed, cancelled
      t.text :message
      t.datetime :sent_at
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :reminders, :remind_at
    add_index :reminders, [:status, :remind_at]
  end
end

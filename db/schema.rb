# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_13_084758) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "calendar_events", force: :cascade do |t|
    t.bigint "entry_id"
    t.bigint "user_id", null: false
    t.string "google_event_id"
    t.string "title", null: false
    t.text "description"
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.string "event_type", default: "plan"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_calendar_events_on_entry_id"
    t.index ["google_event_id"], name: "index_calendar_events_on_google_event_id", unique: true
    t.index ["start_time"], name: "index_calendar_events_on_start_time"
    t.index ["user_id"], name: "index_calendar_events_on_user_id"
  end

  create_table "entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "entry_type", null: false
    t.text "content", null: false
    t.text "transcript"
    t.string "audio_url"
    t.string "audio_file_id"
    t.jsonb "metadata", default: {}
    t.vector "embedding", limit: 1536
    t.string "status", default: "active"
    t.integer "priority", default: 0
    t.datetime "occurred_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_entries_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
    t.index ["entry_type"], name: "index_entries_on_entry_type"
    t.index ["occurred_at"], name: "index_entries_on_occurred_at"
    t.index ["status"], name: "index_entries_on_status"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "reminders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "entry_id"
    t.string "reminder_type", null: false
    t.datetime "remind_at", null: false
    t.string "status", default: "pending"
    t.text "message"
    t.datetime "sent_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_reminders_on_entry_id"
    t.index ["remind_at"], name: "index_reminders_on_remind_at"
    t.index ["status", "remind_at"], name: "index_reminders_on_status_and_remind_at"
    t.index ["user_id"], name: "index_reminders_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "telegram_id", null: false
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "timezone", default: "UTC"
    t.string "language", default: "ru"
    t.text "google_refresh_token"
    t.text "google_access_token"
    t.datetime "google_token_expires_at"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["telegram_id"], name: "index_users_on_telegram_id", unique: true
  end

  add_foreign_key "calendar_events", "entries"
  add_foreign_key "calendar_events", "users"
  add_foreign_key "entries", "users"
  add_foreign_key "reminders", "entries"
  add_foreign_key "reminders", "users"
end

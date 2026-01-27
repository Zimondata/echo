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

ActiveRecord::Schema[8.0].define(version: 2026_01_27_114931) do
  create_table "activity_entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "activity_type", null: false
    t.integer "duration_minutes"
    t.decimal "distance_km", precision: 8, scale: 3
    t.integer "calories_burned"
    t.integer "average_heart_rate"
    t.integer "max_heart_rate"
    t.string "average_pace"
    t.datetime "activity_date", null: false
    t.text "notes"
    t.json "garmin_data", default: {}
    t.string "screenshot_url"
    t.string "status", default: "active"
    t.integer "effort_level"
    t.text "ai_analysis"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_date"], name: "index_activity_entries_on_activity_date"
    t.index ["user_id", "activity_date"], name: "index_activity_entries_on_user_id_and_activity_date"
    t.index ["user_id", "activity_type"], name: "index_activity_entries_on_user_id_and_activity_type"
    t.index ["user_id", "status"], name: "index_activity_entries_on_user_id_and_status"
    t.index ["user_id"], name: "index_activity_entries_on_user_id"
  end

  create_table "calendar_events", force: :cascade do |t|
    t.integer "entry_id"
    t.integer "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.string "event_type", default: "plan"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "all_day", default: false
    t.boolean "done", default: false
    t.string "priority", default: "medium"
    t.string "color"
    t.json "tags", default: []
    t.integer "reminder_minutes"
    t.boolean "reminder_sent", default: false
    t.datetime "deleted_at"
    t.string "life_category", default: "work"
    t.boolean "is_habit", default: false
    t.integer "habit_streak", default: 0
    t.datetime "last_completed_at"
    t.string "recurrence_pattern"
    t.index ["all_day"], name: "index_calendar_events_on_all_day"
    t.index ["deleted_at"], name: "index_calendar_events_on_deleted_at"
    t.index ["done"], name: "index_calendar_events_on_done"
    t.index ["entry_id"], name: "index_calendar_events_on_entry_id"
    t.index ["is_habit"], name: "index_calendar_events_on_is_habit"
    t.index ["life_category"], name: "index_calendar_events_on_life_category"
    t.index ["recurrence_pattern"], name: "index_calendar_events_on_recurrence_pattern"
    t.index ["start_time"], name: "index_calendar_events_on_start_time"
    t.index ["user_id"], name: "index_calendar_events_on_user_id"
  end

  create_table "entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "entry_type", null: false
    t.text "content", null: false
    t.text "transcript"
    t.string "audio_url"
    t.string "audio_file_id"
    t.json "metadata", default: {}
    t.string "status", default: "active"
    t.integer "priority", default: 0
    t.datetime "occurred_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category", default: "inbox"
    t.string "dashboard_status", default: "new"
    t.text "tags"
    t.json "insights", default: {}
    t.datetime "processed_at"
    t.string "group_id"
    t.integer "parent_entry_id"
    t.string "idea_category"
    t.string "idea_status", default: "new"
    t.integer "idea_priority", default: 5
    t.json "research_data"
    t.boolean "quest_generated", default: false
    t.index ["category"], name: "index_entries_on_category"
    t.index ["dashboard_status"], name: "index_entries_on_dashboard_status"
    t.index ["entry_type"], name: "index_entries_on_entry_type"
    t.index ["group_id"], name: "index_entries_on_group_id"
    t.index ["idea_category"], name: "index_entries_on_idea_category"
    t.index ["idea_priority"], name: "index_entries_on_idea_priority"
    t.index ["idea_status"], name: "index_entries_on_idea_status"
    t.index ["occurred_at"], name: "index_entries_on_occurred_at"
    t.index ["parent_entry_id"], name: "index_entries_on_parent_entry_id"
    t.index ["processed_at"], name: "index_entries_on_processed_at"
    t.index ["status"], name: "index_entries_on_status"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "insights", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "insight_type", null: false
    t.string "title", null: false
    t.text "content"
    t.json "data", default: {}
    t.datetime "generated_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_insights_on_expires_at"
    t.index ["generated_at"], name: "index_insights_on_generated_at"
    t.index ["insight_type"], name: "index_insights_on_insight_type"
    t.index ["user_id"], name: "index_insights_on_user_id"
  end

  create_table "login_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.boolean "used", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_login_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_login_tokens_on_user_id"
  end

  create_table "nutrition_entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "entry_id"
    t.decimal "calories", precision: 8, scale: 2
    t.decimal "protein", precision: 6, scale: 2
    t.decimal "fat", precision: 6, scale: 2
    t.decimal "carbs", precision: 6, scale: 2
    t.string "meal_type", null: false
    t.text "food_items"
    t.datetime "recorded_at", null: false
    t.text "meal_description"
    t.string "photo_url"
    t.json "analysis_data", default: {}
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_nutrition_entries_on_entry_id"
    t.index ["meal_type"], name: "index_nutrition_entries_on_meal_type"
    t.index ["recorded_at"], name: "index_nutrition_entries_on_recorded_at"
    t.index ["status"], name: "index_nutrition_entries_on_status"
    t.index ["user_id", "recorded_at"], name: "index_nutrition_entries_on_user_id_and_recorded_at"
    t.index ["user_id"], name: "index_nutrition_entries_on_user_id"
  end

  create_table "quests", force: :cascade do |t|
    t.integer "entry_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "active"
    t.integer "priority", default: 5
    t.datetime "due_date"
    t.json "steps", default: []
    t.integer "completion_rate", default: 0
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date"], name: "index_quests_on_due_date"
    t.index ["entry_id"], name: "index_quests_on_entry_id"
    t.index ["priority"], name: "index_quests_on_priority"
    t.index ["status"], name: "index_quests_on_status"
    t.index ["user_id", "status"], name: "index_quests_on_user_id_and_status"
    t.index ["user_id"], name: "index_quests_on_user_id"
  end

  create_table "reminders", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "entry_id"
    t.string "reminder_type", null: false
    t.datetime "remind_at", null: false
    t.string "status", default: "pending"
    t.text "message"
    t.datetime "sent_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "smart_type"
    t.string "smart_trigger"
    t.json "related_entry_ids", default: []
    t.integer "confidence_score"
    t.json "ai_context", default: {}
    t.json "action_buttons", default: []
    t.string "priority", default: "medium"
    t.string "recurrence_rule"
    t.string "user_feedback"
    t.index ["confidence_score"], name: "index_reminders_on_confidence_score"
    t.index ["entry_id"], name: "index_reminders_on_entry_id"
    t.index ["priority"], name: "index_reminders_on_priority"
    t.index ["remind_at"], name: "index_reminders_on_remind_at"
    t.index ["smart_type"], name: "index_reminders_on_smart_type"
    t.index ["status", "remind_at"], name: "index_reminders_on_status_and_remind_at"
    t.index ["user_id"], name: "index_reminders_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.binary "payload", limit: 536870912, null: false
    t.datetime "created_at", null: false
    t.integer "channel_hash", limit: 8, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
    t.index ["id"], name: "index_solid_cable_messages_on_id", unique: true
  end

  create_table "telegram_auth_sessions", force: :cascade do |t|
    t.string "session_token", null: false
    t.bigint "telegram_id"
    t.integer "user_id"
    t.string "status", default: "pending", null: false
    t.string "initiated_from"
    t.string "client_ip"
    t.string "user_agent"
    t.datetime "expires_at", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_telegram_auth_sessions_on_expires_at"
    t.index ["session_token"], name: "index_telegram_auth_sessions_on_session_token", unique: true
    t.index ["status", "expires_at"], name: "index_telegram_auth_sessions_on_status_and_expires_at"
    t.index ["telegram_id"], name: "index_telegram_auth_sessions_on_telegram_id"
    t.index ["user_id"], name: "index_telegram_auth_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "telegram_id", null: false
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "timezone", default: "UTC"
    t.string "language", default: "ru"
    t.json "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "last_entry_ids"
    t.datetime "last_entry_timestamp"
    t.index ["telegram_id"], name: "index_users_on_telegram_id", unique: true
  end

  add_foreign_key "activity_entries", "users"
  add_foreign_key "calendar_events", "entries"
  add_foreign_key "calendar_events", "users"
  add_foreign_key "entries", "users"
  add_foreign_key "insights", "users"
  add_foreign_key "login_tokens", "users"
  add_foreign_key "nutrition_entries", "entries"
  add_foreign_key "nutrition_entries", "users"
  add_foreign_key "quests", "entries"
  add_foreign_key "quests", "users"
  add_foreign_key "reminders", "entries"
  add_foreign_key "reminders", "users"
  add_foreign_key "telegram_auth_sessions", "users"
end

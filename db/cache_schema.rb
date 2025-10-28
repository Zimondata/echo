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

ActiveRecord::Schema[8.0].define(version: 2025_10_27_210317) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "activity_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "activity_type", null: false
    t.integer "duration_minutes"
    t.decimal "distance_km", precision: 8, scale: 3
    t.integer "calories_burned"
    t.integer "average_heart_rate"
    t.integer "max_heart_rate"
    t.string "average_pace"
    t.datetime "activity_date", null: false
    t.text "notes"
    t.jsonb "garmin_data", default: {}
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
    t.bigint "entry_id"
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.string "event_type", default: "plan"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "all_day", default: false
    t.boolean "done", default: false
    t.string "priority", default: "medium"
    t.string "color"
    t.jsonb "tags", default: []
    t.integer "reminder_minutes"
    t.boolean "reminder_sent", default: false
    t.datetime "deleted_at"
    t.index ["all_day"], name: "index_calendar_events_on_all_day"
    t.index ["deleted_at"], name: "index_calendar_events_on_deleted_at"
    t.index ["done"], name: "index_calendar_events_on_done"
    t.index ["entry_id"], name: "index_calendar_events_on_entry_id"
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
    t.string "category", default: "inbox"
    t.string "dashboard_status", default: "new"
    t.text "tags"
    t.jsonb "insights", default: {}
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
    t.index ["embedding"], name: "index_entries_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
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
    t.bigint "user_id", null: false
    t.string "insight_type", null: false
    t.string "title", null: false
    t.text "content"
    t.jsonb "data", default: {}
    t.datetime "generated_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_insights_on_expires_at"
    t.index ["generated_at"], name: "index_insights_on_generated_at"
    t.index ["insight_type"], name: "index_insights_on_insight_type"
    t.index ["user_id"], name: "index_insights_on_user_id"
  end

  create_table "nutrition_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "entry_id"
    t.decimal "calories", precision: 8, scale: 2
    t.decimal "protein", precision: 6, scale: 2
    t.decimal "fat", precision: 6, scale: 2
    t.decimal "carbs", precision: 6, scale: 2
    t.string "meal_type", null: false
    t.text "food_items"
    t.datetime "recorded_at", null: false
    t.text "meal_description"
    t.string "photo_url"
    t.jsonb "analysis_data", default: {}
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
    t.bigint "entry_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "active"
    t.integer "priority", default: 5
    t.datetime "due_date"
    t.json "steps", default: []
    t.integer "completion_rate", default: 0
    t.bigint "user_id", null: false
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "telegram_id", null: false
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "timezone", default: "UTC"
    t.string "language", default: "ru"
    t.jsonb "settings", default: {}
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
  add_foreign_key "nutrition_entries", "entries"
  add_foreign_key "nutrition_entries", "users"
  add_foreign_key "quests", "entries"
  add_foreign_key "quests", "users"
  add_foreign_key "reminders", "entries"
  add_foreign_key "reminders", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end

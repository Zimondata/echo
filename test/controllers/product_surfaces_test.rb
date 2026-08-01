require "test_helper"

class ProductSurfacesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    assert_response :success
  end

  test "birthday product surfaces render for the signed-in user" do
    {
      dashboard_path => "Сейчас",
      calendar_events_path(view: "week") => "План",
      diary_entries_path => "Дневник",
      reminders_path => "Напоминания",
      health_path => "Здоровье",
      settings_path => "Настройки"
    }.each do |path, text|
      get path
      assert_response :success, "expected #{path} to render"
      assert_includes response.body, text
    end
  end

  test "signed-in root opens owner Home without the external showcase" do
    get root_path

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select "[data-primary-action]", count: 1
    assert_not_includes response.body, "fonts.googleapis.com"
    assert_not_includes response.body, "unpkg.com"
  end

  test "desktop and mobile permanent navigation share exactly five destinations" do
    get dashboard_path

    expected = [ "Главная", "План", "Дневник", "Напоминания", "Здоровье" ]
    assert_select "nav[aria-label='Основная навигация'] [data-permanent-destination]", count: 5 do |links|
      assert_equal expected, links.map { |link| link.text.strip }
    end
    assert_select "nav[aria-label='Мобильная навигация'] [data-permanent-destination]", count: 5 do |links|
      assert_equal expected, links.map { |link| link.text.strip }
    end
    assert_select "[data-permanent-destination]", text: /Задачи|Входящие|Агенты|Обзоры|Настройки/, count: 0
    assert_select "header a[href^='#{inbox_path}']", count: 0
  end

  test "birthday layout has no runtime CDN or Google font dependency" do
    get dashboard_path

    assert_not_includes response.body, "cdn.tailwindcss.com"
    assert_not_includes response.body, "fonts.googleapis.com"
    assert_not_includes response.body, "fonts.gstatic.com"
  end

  test "layout exposes only the chosen Violet and Lavender pair" do
    get calendar_events_path(view: "month", theme: "light-violet")

    assert_response :success
    assert_select "html[data-theme='dark-violet'][data-color-scheme='dark']", count: 1
    assert_select "html[data-font]", count: 0
    assert_select "[data-style-picker]", count: 0
    assert_select "[data-theme-toggle]", count: 1
    assert_includes response.body, "new URLSearchParams(window.location.search).get(\"theme\")"
    assert_not_includes response.body, "dark-cobalt"
    assert_not_includes response.body, "dark-sage"
    assert_not_includes response.body, "light-cobalt"
    assert_not_includes response.body, "light-sage"
  end

  test "settings keeps an explicit session exit" do
    get settings_path

    assert_response :success
    assert_select "form[action='#{logout_path}'] input[name='_method'][value='delete']", count: 1
    assert_select "button", text: "Выйти из Echo", count: 1
  end

  test "manual diary capture persists only in the current user's journal" do
    assert_difference "@user.entries.count", 1 do
      post entries_path, params: { entry: { content: "Важный личный эпизод", tags: "семья, день" } }
    end

    assert_redirected_to diary_entries_path
    entry = @user.entries.order(:created_at).last
    assert_equal "diary", entry.entry_type
    assert_equal "life", entry.category
    assert_equal [ "семья", "день" ], entry.tag_list
  end

  test "manual reminder can be created and snoozed" do
    assert_difference "@user.reminders.count", 1 do
      post reminders_path, params: { reminder: { message: "Позвонить маме", remind_at: "2026-08-01T10:00", priority: "high" } }
    end

    reminder = @user.reminders.order(:created_at).last
    assert_equal "pending", reminder.status
    assert_equal "one_time", reminder.reminder_type
    assert_equal "2026-08-01 10:00", reminder.remind_at.in_time_zone(@user.timezone).strftime("%F %H:%M")
    previous_time = reminder.remind_at

    post snooze_reminder_path(reminder), params: { duration: 60 }
    assert_redirected_to reminders_path
    assert_operator reminder.reload.remind_at, :>, previous_time
  end

  test "task quick add can return to the task workspace" do
    assert_difference "@user.tasks.count", 1 do
      post tasks_path, params: { return_to: "tasks", task: { title: "Проверить продуктовый поток", next_action: "Открыть Today" } }
    end

    assert_redirected_to tasks_path(status: "inbox")
  end

  test "settings update is scoped to safe workspace preferences" do
    patch settings_path, params: { user: { timezone: "Europe/Madrid", language: "ru", quiet_start: "22:30", quiet_end: "07:00" } }

    assert_redirected_to settings_path
    @user.reload
    assert_equal "Europe/Madrid", @user.timezone
    assert_equal "22:30", @user.settings["quiet_start"]
    assert_equal "07:00", @user.settings["quiet_end"]
  end

  test "manual reminder rejects nonexistent local wall time" do
    @user.update!(timezone: "Europe/Madrid")

    assert_no_difference "@user.reminders.count" do
      post reminders_path, params: { reminder: { message: "DST gap", remind_at: "2026-03-29T02:30", priority: "medium" } }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "переход времени"
  end

  test "settings reject invalid timezone and malformed quiet hours" do
    patch settings_path, params: { user: { timezone: "Not/AZone", language: "ru", quiet_start: "nonsense", quiet_end: "07:00" } }

    assert_response :unprocessable_entity
    @user.reload
    assert_equal "Europe/Moscow", @user.timezone
    assert_empty @user.settings
  end

  test "blank quiet hours explicitly clear old values" do
    @user.update!(settings: { "quiet_start" => "22:30", "quiet_end" => "07:00" })

    patch settings_path, params: { user: { timezone: "Europe/Moscow", language: "ru", quiet_start: "", quiet_end: "" } }

    assert_redirected_to settings_path
    assert_nil @user.reload.settings["quiet_start"]
    assert_nil @user.settings["quiet_end"]
  end
end

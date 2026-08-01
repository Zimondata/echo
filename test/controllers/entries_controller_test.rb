require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    assert_response :success
  end

  test "renders diary" do
    get diary_entries_url
    assert_response :success
    assert_select "form[action='#{entries_path}']"
  end

  test "cannot read another user's entry" do
    get entry_url(entries(:two))
    assert_redirected_to entries_path
  end

  test "datetime-local round-trips through the owner's timezone after DST transition" do
    @user.update!(timezone: "Europe/Madrid")

    post entries_path, params: { entry: { content: "После перевода часов", occurred_at: "2026-03-29T03:30", tags: "" } }

    assert_redirected_to diary_entries_path
    entry = @user.entries.order(:created_at).last
    assert_equal "2026-03-29 03:30", entry.occurred_at.in_time_zone(@user.timezone).strftime("%F %H:%M")
    get diary_entries_path
    assert_includes response.body, "После перевода часов"
    assert_select "time", text: /03:30/
  end

  test "quick note returns to the same calendar period" do
    assert_difference "@user.entries.count", 1 do
      post entries_path, params: {
        return_to: "calendar",
        return_view: "week",
        return_date: "2026-08-03",
        entry: { content: "Мысль из календаря", occurred_at: "2026-08-03T10:15", tags: "echo, тест" }
      }
    end

    assert_redirected_to calendar_events_path(date: "2026-08-03", view: "week")
    assert_equal "Мысль из календаря", @user.entries.order(:created_at).last.content
  end

  test "diary does not expose foreign entries or unsupported capture claims" do
    users(:moscow_user).entries.create!(entry_type: "diary", content: "ЧУЖОЙ ДНЕВНИК", status: "active", occurred_at: Time.current)

    get diary_entries_path

    assert_not_includes response.body, "ЧУЖОЙ ДНЕВНИК"
    assert_no_match(/голос|фото|файл|настроени|авто.*извлеч/i, response.body)
  end
end

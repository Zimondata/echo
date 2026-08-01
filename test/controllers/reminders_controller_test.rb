require "test_helper"

class RemindersControllerTest < ActionDispatch::IntegrationTest
  setup do
    auth = TelegramAuthSession.create!
    auth.confirm!(users(:john))
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    assert_response :success
  end

  test "renders reminders and creation form" do
    assert_no_enqueued_jobs { get reminders_url }
    assert_response :success
    assert_select "form[action='#{reminders_path}']"
    assert_includes response.body, "Локальная альфа сохраняет расписание, но доставка и фоновые jobs выключены"
    assert_no_match(/Hard alerts|гарант|подтвержден|recurring|повторяющ/i, response.body)
  end

  test "renders reminder priority in Russian" do
    users(:john).reminders.create!(message: "Позвонить", remind_at: 1.hour.from_now, priority: "high", reminder_type: "one_time", status: "pending")

    get reminders_url

    assert_response :success
    assert_includes response.body, "Срочное"
    assert_select "span", text: "high", count: 0
  end
end

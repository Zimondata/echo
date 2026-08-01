require "test_helper"

class Api::V1::RemindersOwnershipTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @other = users(:utc_user)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
  end

  test "cannot attach a reminder to another user's entry" do
    foreign_entry = @other.entries.create!(
      entry_type: "diary", content: "Чужой приватный текст", status: "active",
      category: "life", dashboard_status: "processed", occurred_at: Time.current
    )

    post "/api/v1/reminders", params: {
      message: "Напомнить", remind_at: 1.hour.from_now.iso8601,
      reminder_type: "one_time", entry_id: foreign_entry.id
    }, as: :json

    assert_response :not_found
    assert_not Reminder.exists?(user: @user, entry_id: foreign_entry.id)
  end

  test "update ignores attempted user reassignment" do
    reminder = @user.reminders.create!(
      message: "Моё", remind_at: 1.hour.from_now,
      reminder_type: "one_time", status: "pending"
    )

    patch "/api/v1/reminders/#{reminder.id}", params: {
      message: "Обновлено", user_id: @other.id
    }, as: :json

    assert_response :success
    assert_equal @user.id, reminder.reload.user_id
    assert_equal "Обновлено", reminder.message
  end

  test "partial update preserves the existing reminder type" do
    reminder = @user.reminders.create!(
      message: "Умное", remind_at: 1.hour.from_now,
      reminder_type: "smart", smart_type: "idea", status: "pending"
    )

    patch "/api/v1/reminders/#{reminder.id}", params: { message: "Обновлено" }, as: :json

    assert_response :success
    assert_equal "smart", reminder.reload.reminder_type
    assert_equal "idea", reminder.smart_type
  end

  test "manual send_now route is not exposed" do
    reminder = @other.reminders.create!(
      message: "Чужое", remind_at: 1.hour.ago,
      reminder_type: "one_time", status: "pending"
    )

    post "/api/reminders/#{reminder.id}/send_now", as: :json

    assert_response :not_found
    assert_equal "pending", reminder.reload.status
  end
end

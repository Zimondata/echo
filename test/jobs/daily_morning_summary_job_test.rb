require "test_helper"
require "minitest/mock"

class DailyMorningSummaryJobTest < ActiveJob::TestCase
  FakeTelegram = Struct.new(:messages) do
    def send_message(**payload)
      messages << payload
      true
    end
  end

  setup do
    @user = users(:john)
    @today = Time.current.in_time_zone(@user.timezone).to_date
  end

  test "sends one summary per active user with Telegram identity" do
    service = FakeTelegram.new([])

    Telegram::BotService.stub :send_message, ->(**payload) { service.send_message(**payload) } do
      DailyMorningSummaryJob.perform_now
    end

    expected = User.active.where.not(telegram_id: nil).count
    assert_operator service.messages.length, :>=, expected
    assert service.messages.all? { |message| message[:text].present? }
  end

  test "builds a message containing today's event and reminder" do
    event = @user.calendar_events.create!(
      title: "Echo planning",
      start_time: Time.current.in_time_zone(@user.timezone).change(hour: 10),
      end_time: Time.current.in_time_zone(@user.timezone).change(hour: 11),
      event_type: "meeting",
      priority: "medium",
      all_day: false,
      done: false,
      metadata: {}
    )
    reminder = @user.reminders.create!(
      message: "Check the launch",
      remind_at: Time.current.in_time_zone(@user.timezone).change(hour: 14),
      reminder_type: "one_time",
      status: "pending",
      priority: "medium",
      metadata: {}
    )

    message = DailyMorningSummaryJob.new.send(:build_morning_message, @user, @today, [event], [reminder])

    assert_includes message, "Echo planning"
    assert_includes message, "Check the launch"
    assert_includes message, "Планы на сегодня"
  end

  test "builds a calm free-day message" do
    message = DailyMorningSummaryJob.new.send(:build_morning_message, @user, @today, [], [])

    assert_includes message, "свободный день"
    assert_includes message, "Время для отдыха"
  end

  test "formats event time in the user's timezone" do
    event = Struct.new(:start_time, :title, :done?, :all_day?).new(
      Time.utc(2026, 7, 31, 8, 0), "Timezone check", false, false
    )

    message = DailyMorningSummaryJob.new.send(:build_morning_message, @user, @today, [event], [])

    assert_includes message, "11:00 - Timezone check"
  end
end

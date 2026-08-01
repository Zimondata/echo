require "test_helper"
require "minitest/mock"

class SendRemindersJobTest < ActiveJob::TestCase
  setup do
    @user = users(:john)
    @user.update!(settings: { "quiet_start" => "22:30", "quiet_end" => "07:00" })
    @zone = ActiveSupport::TimeZone[@user.timezone]
  end

  test "soft reminders wait until quiet hours end" do
    travel_to @zone.local(2026, 7, 31, 23, 0) do
      reminder = create_due_reminder(priority: "medium")

      Telegram::BotService.stub :send_message, ->(**) { flunk "soft reminder must not be sent during quiet hours" } do
        SendRemindersJob.perform_now
      end

      reminder.reload
      assert_equal "pending", reminder.status
      assert_equal @zone.local(2026, 8, 1, 7, 0).to_i, reminder.remind_at.to_i
    end
  end

  test "high-priority reminders bypass quiet hours" do
    travel_to @zone.local(2026, 7, 31, 23, 0) do
      reminder = create_due_reminder(priority: "high")
      deliveries = []

      Telegram::BotService.stub :send_message, ->(**payload) { deliveries << payload; true } do
        SendRemindersJob.perform_now
      end

      assert_equal "sent", reminder.reload.status
      assert_equal 1, deliveries.length
      assert_equal @user.telegram_id, deliveries.first[:chat_id]
    end
  end

  test "failed recurring delivery neither marks sent nor creates recurrence" do
    @user.update!(settings: {})
    reminder = create_due_reminder(priority: "medium", reminder_type: "recurring")

    assert_no_difference "Reminder.count" do
      Telegram::BotService.stub(:send_message, false) { SendRemindersJob.perform_now }
    end

    assert_equal "pending", reminder.reload.status
  end

  test "delivery exception releases claim without creating recurrence" do
    @user.update!(settings: {})
    reminder = create_due_reminder(priority: "medium", reminder_type: "recurring")

    assert_no_difference "Reminder.count" do
      Telegram::BotService.stub(:send_message, ->(**) { raise "provider down" }) do
        SendRemindersJob.perform_now
      end
    end

    assert_equal "pending", reminder.reload.status
  end

  test "successful recurring reminder creates exactly one successor" do
    @user.update!(settings: {})
    reminder = create_due_reminder(priority: "medium", reminder_type: "recurring")
    deliveries = 0

    Telegram::BotService.stub(:send_message, ->(**) { deliveries += 1; true }) do
      assert_difference "Reminder.count", 1 do
        SendRemindersJob.perform_now
        SendRemindersJob.perform_now
      end
    end

    assert_equal "sent", reminder.reload.status
    assert_equal 1, deliveries
  end

  test "invalid recurring metadata fails before external delivery" do
    @user.update!(settings: {})
    reminder = create_due_reminder(priority: "medium", reminder_type: "recurring")
    reminder.update!(metadata: { "interval_hours" => 3, "start_time" => "bad-clock" })
    deliveries = 0

    assert_no_difference "Reminder.count" do
      Telegram::BotService.stub(:send_message, ->(**) { deliveries += 1; true }) do
        SendRemindersJob.perform_now
      end
    end

    assert_equal 0, deliveries
    assert_equal "pending", reminder.reload.status
  end

  test "malformed legacy quiet hours fail closed for normal reminders" do
    @user.update!(settings: { "quiet_start" => "not-a-clock", "quiet_end" => "07:00" })
    reminder = create_due_reminder(priority: "medium")
    original_time = reminder.remind_at
    deliveries = 0

    Telegram::BotService.stub :send_message, ->(**) { deliveries += 1; true } do
      SendRemindersJob.perform_now
    end

    assert_equal 0, deliveries
    assert_equal "pending", reminder.reload.status
    assert_operator reminder.remind_at, :>, original_time
  end

  test "daily recurrence preserves the user's local wall clock across DST" do
    @user.update!(timezone: "Europe/Madrid", settings: {})
    zone = Time.find_zone!("Europe/Madrid")
    reminder = @user.reminders.create!(
      message: "Утренний ритуал",
      remind_at: zone.local(2026, 3, 28, 9, 0),
      reminder_type: "recurring",
      status: "pending",
      priority: "medium",
      recurrence_rule: "interval_hours",
      metadata: { "interval_hours" => 24 }
    )

    Telegram::BotService.stub :send_message, ->(**) { true } do
      SendRemindersJob.perform_now
    end

    next_reminder = @user.reminders.where.not(id: reminder.id).order(:created_at).last
    next_local = next_reminder.remind_at.in_time_zone(zone)
    assert_equal Date.new(2026, 3, 29), next_local.to_date
    assert_equal [ 9, 0 ], [ next_local.hour, next_local.min ]
  end

  private

  def create_due_reminder(priority:, reminder_type: "one_time")
    @user.reminders.create!(
      message: "Проверить обязательство",
      remind_at: 1.minute.ago,
      reminder_type: reminder_type,
      status: "pending",
      priority: priority,
      metadata: { "interval_hours" => 3 }
    )
  end
end

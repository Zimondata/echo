require "test_helper"

class DailyMorningSummaryJobTest < ActiveJob::TestCase
  def setup
    @user = users(:john)
    @today = Date.current.in_time_zone(@user.timezone)
  end

  test "sends morning summary to all active users" do
    # Mock Telegram service
    telegram_service = Minitest::Mock.new
    telegram_service.expect :send_message, true, [Hash]
    
    Telegram::BotService.stub :instance, telegram_service do
      assert_performed_jobs 1 do
        DailyMorningSummaryJob.perform_now
      end
    end
    
    telegram_service.verify
  end

  test "builds message for day with events" do
    # Create test events for today
    calendar_events(:meeting).update!(
      start_time: @today.beginning_of_day + 10.hours,
      user: @user
    )
    
    reminders(:dentist).update!(
      remind_at: @today.beginning_of_day + 14.hours,
      user: @user
    )

    job = DailyMorningSummaryJob.new
    events = @user.calendar_events.active.where(start_time: @today.beginning_of_day..@today.end_of_day)
    reminders = @user.reminders.pending.where(remind_at: @today.beginning_of_day..@today.end_of_day)
    
    message = job.send(:build_morning_message, @user, @today, events, reminders)
    
    assert_includes message, "Доброе утро, #{@user.full_name}!"
    assert_includes message, "События по времени:"
    assert_includes message, "Напоминания:"
  end

  test "builds message for free day" do
    job = DailyMorningSummaryJob.new
    message = job.send(:build_morning_message, @user, @today, [], [])
    
    assert_includes message, "У вас свободный день!"
    assert_includes message, "Время для отдыха"
  end

  test "handles timezone correctly" do
    moscow_user = users(:moscow_user)
    
    job = DailyMorningSummaryJob.new
    
    # Mock the method to verify timezone usage
    job.stub :send_morning_summary_to_user, true do
      job.stub :User, -> { mock_users = Minitest::Mock.new
                           mock_users.expect :active, [moscow_user]
                           mock_users.expect :find_each, [moscow_user] do |&block|
                             block.call(moscow_user)
                           end
                           mock_users } do
        job.perform
      end
    end
  end

  private

  def mock_telegram_service
    mock = Minitest::Mock.new
    mock.expect :send_message, true, [Hash]
    mock
  end
end
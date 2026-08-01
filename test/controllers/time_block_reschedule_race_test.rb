require "test_helper"

class TimeBlockRescheduleRaceTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @user = users(:utc_user)
    @title = "QA reschedule task lock boundary"
    @user.tasks.where(title: @title).destroy_all
    @task = @user.tasks.create!(title: @title, owner_type: "user", status: "scheduled")
    @block = @task.time_blocks.create!(
      starts_at: Time.utc(2026, 8, 3, 10),
      ends_at: Time.utc(2026, 8, 3, 10, 30),
      source: "manual",
      previous_task_status: "inbox"
    )
    @auth_session = TelegramAuthSession.create!
    @auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: @auth_session.session_token }
    assert_response :success
  end

  teardown do
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
    @racer&.join(5)
    @user.tasks.where(title: @title).destroy_all
    @auth_session&.destroy!
  end

  test "task writer is serialized behind the complete reschedule transaction" do
    started = Queue.new
    finished = Queue.new
    callback_checks = Queue.new

    @subscriber = ActiveSupport::Notifications.subscribe("time_block.reschedule.task_claimed") do |_name, _start, _finish, _id, payload|
      next unless payload[:task_id] == @task.id

      @racer = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          started << true
          Task.find(@task.id).update!(status: "completed")
          finished << :updated
        rescue StandardError => error
          finished << error
        end
      end

      started.pop
      sleep 0.1
      callback_checks << @racer.alive?
    end

    patch task_time_block_url(@task, @block), params: {
      task: { lock_version: @task.lock_version },
      time_block: {
        lock_version: @block.lock_version,
        local_date: "2026-08-04",
        local_time: "14:15",
        duration_minutes: "90",
        locked: "1",
        timezone: @user.timezone
      }
    }

    assert_response :redirect
    assert callback_checks.pop, "the competing Task writer should still be blocked while reschedule owns the Task boundary"
    assert @racer.join(5), "the competing Task writer did not finish after reschedule committed"
    assert_equal :updated, finished.pop
    assert_equal "completed", @task.reload.status
    assert_equal "2026-08-04 14:15", @block.reload.starts_at.in_time_zone(@user.timezone).strftime("%F %R")
    assert_equal 90, @block.duration_minutes
    assert_predicate @block, :locked?
  end
end

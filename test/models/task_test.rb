require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
  end

  test "valid with only a user and a title" do
    task = Task.new(user: @user, title: "Позвонить в клинику")

    assert task.valid?, task.errors.full_messages.to_sentence
  end

  test "requires a user" do
    task = Task.new(title: "Без владельца")

    assert_not task.valid?
    assert_includes task.errors.attribute_names, :user
  end

  test "requires a title" do
    task = Task.new(user: @user, title: "  ")

    assert_not task.valid?
    assert_includes task.errors.attribute_names, :title
  end

  test "limits title to 255 characters" do
    assert Task.new(user: @user, title: "я" * 255).valid?
    assert_not Task.new(user: @user, title: "я" * 256).valid?
  end

  test "next_action, estimate_minutes and due_on are optional" do
    task = Task.new(user: @user, title: "Минимальная задача")

    assert task.valid?
    assert_nil task.next_action
    assert_nil task.estimate_minutes
    assert_nil task.due_on
  end

  test "defaults owner_type to user and status to inbox" do
    task = Task.create!(user: @user, title: "Разобрать почту")

    assert_equal "user", task.owner_type
    assert_equal "inbox", task.status
    assert_equal 0, task.lock_version
  end

  test "allows the four canonical owner types and rejects others" do
    %w[user assistant collaborator system].each do |owner_type|
      task = Task.new(user: @user, title: "Задача", owner_type: owner_type)
      assert task.valid?, "expected #{owner_type} to be a valid owner_type"
    end

    task = Task.new(user: @user, title: "Задача", owner_type: "robot")
    assert_not task.valid?
    assert_includes task.errors.attribute_names, :owner_type
  end

  test "allows the full status vocabulary and rejects others" do
    %w[inbox next scheduled waiting someday completed dropped].each do |status|
      task = Task.new(user: @user, title: "Задача", status: status)
      assert task.valid?, "expected #{status} to be a valid status"
    end

    task = Task.new(user: @user, title: "Задача", status: "archived")
    assert_not task.valid?
    assert_includes task.errors.attribute_names, :status
  end

  test "estimate_minutes must be a positive integer when present" do
    assert Task.new(user: @user, title: "Задача", estimate_minutes: 15).valid?
    assert_not Task.new(user: @user, title: "Задача", estimate_minutes: 0).valid?
    assert_not Task.new(user: @user, title: "Задача", estimate_minutes: -5).valid?
  end

  test "rejects optionals that cannot be cast instead of silently dropping them" do
    estimate = Task.new(user: @user, title: "Задача", estimate_minutes: "abc")
    due_date = Task.new(user: @user, title: "Задача", due_on: "not-a-date")

    assert_not estimate.valid?
    assert_includes estimate.errors.attribute_names, :estimate_minutes
    assert_not due_date.valid?
    assert_includes due_date.errors.attribute_names, :due_on
  end

  test "drop reason is optional, stripped and limited to 500 characters" do
    task = Task.new(user: @user, title: "Задача", drop_reason: "  Больше не нужно  ")

    assert task.valid?
    assert_equal "Больше не нужно", task.drop_reason
    assert Task.new(user: @user, title: "Задача", drop_reason: nil).valid?
    assert_not Task.new(user: @user, title: "Задача", drop_reason: "я" * 501).valid?
  end

  test "active scope excludes soft-deleted tasks" do
    assert_includes Task.active, tasks(:inbox_task)
    assert_not_includes Task.active, tasks(:deleted_task)
  end

  test "unscheduled scope keeps inbox and next while hiding deferred, waiting, scheduled and closed work" do
    unscheduled = Task.where(user: @user).unscheduled

    assert_includes unscheduled, tasks(:inbox_task)
    assert_includes unscheduled, tasks(:next_task)
    assert_not_includes unscheduled, tasks(:someday_task)
    assert_not_includes unscheduled, tasks(:scheduled_task)

    %w[completed dropped].each do |status|
      closed = Task.create!(user: @user, title: "Закрытая #{status}", status: status)
      assert_not_includes Task.where(user: @user).unscheduled, closed
    end

    waiting = Task.create!(user: @user, title: "Жду ответа", status: "waiting")
    assert_not_includes Task.where(user: @user).unscheduled, waiting
  end

  test "soft_delete! hides the task without destroying the row" do
    task = tasks(:inbox_task)

    assert_no_difference "Task.count" do
      task.soft_delete!
    end

    assert task.reload.deleted_at.present?
    assert_not_includes Task.active, task
  end

  test "destroying a user destroys their tasks" do
    user = User.create!(telegram_id: 424242, timezone: "UTC", language: "ru")
    user.tasks.create!(title: "Задача на удаление")

    assert_difference "Task.count", -1 do
      user.destroy
    end
  end
end

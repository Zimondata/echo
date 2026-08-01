require "test_helper"

class TimeBlockTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:inbox_task)
  end

  test "requires a positive interval and bounded source and previous status" do
    block = TimeBlock.new(
      task: @task,
      starts_at: Time.zone.parse("2026-08-03 10:00"),
      ends_at: Time.zone.parse("2026-08-03 09:00"),
      source: "assistant",
      previous_task_status: "waiting"
    )

    assert_not block.valid?
    assert block.errors[:ends_at].any?
    assert block.errors[:source].any?
    assert block.errors[:previous_task_status].any?
  end

  test "active scope excludes cancelled history" do
    active = TimeBlock.create!(
      task: @task,
      starts_at: Time.zone.parse("2026-08-03 10:00"),
      ends_at: Time.zone.parse("2026-08-03 10:30"),
      previous_task_status: "inbox"
    )
    cancelled = TimeBlock.create!(
      task: tasks(:next_task),
      starts_at: Time.zone.parse("2026-08-03 11:00"),
      ends_at: Time.zone.parse("2026-08-03 11:30"),
      previous_task_status: "next",
      cancelled_at: Time.current
    )

    assert_includes TimeBlock.active, active
    assert_not_includes TimeBlock.active, cancelled
  end

  test "database allows only one active block per task but keeps cancelled history" do
    first = TimeBlock.create!(task: @task, starts_at: Time.zone.parse("2026-08-03 10:00"), ends_at: Time.zone.parse("2026-08-03 10:30"), previous_task_status: "inbox")

    duplicate = TimeBlock.new(task: @task, starts_at: Time.zone.parse("2026-08-03 11:00"), ends_at: Time.zone.parse("2026-08-03 11:30"), previous_task_status: "inbox")
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }

    first.update!(cancelled_at: Time.current)
    assert_nothing_raised { duplicate.save! }
  end
end

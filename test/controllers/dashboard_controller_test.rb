require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    assert_response :success
  end

  test "renders the Today surface" do
    get dashboard_url
    assert_response :success
    assert_select "[data-command-dashboard]", count: 1
    assert_select "[data-command-focus]", count: 1
    assert_select "[data-command-dayline]", count: 1
    assert_select "h1"
    assert_select "a", text: "План"
    assert_select "[data-primary-action]", count: 1
  end

  test "Today chooses the nearest item across events and flexible blocks" do
    zone = Time.find_zone!(@user.timezone)
    date = Date.new(2026, 8, 3)
    event = @user.calendar_events.create!(
      title: "Ближайшая встреча",
      start_time: zone.local(2026, 8, 3, 10),
      end_time: nil,
      event_type: "meeting",
      priority: "medium"
    )
    task = @user.tasks.create!(title: "Поздняя задача", status: "scheduled")
    task.time_blocks.create!(
      starts_at: zone.local(2026, 8, 3, 15),
      ends_at: zone.local(2026, 8, 3, 16),
      previous_task_status: "next"
    )

    travel_to zone.local(2026, 8, 3, 9) do
      get dashboard_url(date: date.iso8601)
    end

    assert_response :success
    assert_select "[data-next-timed-event]", text: /#{event.title}/
  end

  test "GET is read-only and does not expire approvals" do
    proposal = @user.captures.create!(source_type: "text", source_ref: "home-read-only", idempotency_key: "home-read-only", raw_text: "x", occurred_at: Time.current).intent_proposals.create!(intent_type: "task", title: "read only", owner_type: "user", risk_level: "reversible", source_span: { start: 0, end: 1 })
    run = @user.agent_runs.create!(intent_proposal: proposal, objective: "Не менять", definition_of_done: "Не изменено", status: "waiting_approval")
    approval = run.approval_requests.create!(risk_reason: "test", requested_at: 2.hours.ago, action_payload: { action: "test" }, payload_digest: "read-only-digest", expires_at: 1.hour.ago)

    assert_no_changes -> { approval.reload.attributes } do
      assert_no_changes -> { run.reload.attributes } do
        get dashboard_url
      end
    end
    assert_response :success
  end

  test "home separates one now action, timed event, bounded needs, timeline types and owner health" do
    @user.tasks.update_all(deleted_at: Time.current)
    @user.calendar_events.update_all(deleted_at: Time.current)
    zone = Time.find_zone!(@user.timezone)
    foreign = users(:moscow_user)
    foreign.tasks.create!(title: "ЧУЖАЯ ЗАДАЧА", status: "next")
    foreign.nutrition_entries.create!(meal_type: "lunch", calories: 999, protein: 1, fat: 1, carbs: 1, recorded_at: zone.local(2026, 8, 3, 12))
    task = @user.tasks.create!(title: "Мой следующий шаг", status: "next")
    @user.tasks.create!(title: "Нужно мне", status: "inbox")
    event = @user.calendar_events.create!(title: "Моё жёсткое", start_time: zone.local(2026, 8, 3, 11), end_time: zone.local(2026, 8, 3, 12), all_day: false)
    block_task = @user.tasks.create!(title: "Мой блок", status: "scheduled")
    block_task.time_blocks.create!(starts_at: zone.local(2026, 8, 3, 14), ends_at: zone.local(2026, 8, 3, 15), previous_task_status: "next")

    travel_to zone.local(2026, 8, 3, 9) do
      get dashboard_url(date: "2026-08-03")
    end

    assert_select "[data-now-item]", count: 1, text: /#{task.title}/
    assert_select "[data-primary-action]", count: 1
    assert_select "[data-next-timed-event]", count: 1, text: /#{event.title}/
    assert_select "[data-needs-me-item]", maximum: 5
    assert_select "[data-timeline-kind='calendar-event']", minimum: 1
    assert_select "[data-timeline-kind='time-block']", minimum: 1
    assert_select "[data-health-pulse]", text: /Нет данных/
    assert_not_includes response.body, "ЧУЖАЯ ЗАДАЧА"
    assert_not_includes response.body, "999"
    assert_not_includes response.body, "Ассистент делает"
    assert_not_includes response.body, "Inbox"
  end
end

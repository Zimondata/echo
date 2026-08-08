require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    assert_response :success
  end

  test "unauthenticated create redirects and stores nothing" do
    reset!

    assert_no_difference "Task.count" do
      post tasks_url, params: { task: { title: "Задача без входа" } }
    end

    assert_redirected_to root_path
  end

  test "creates a task from the title-only quick add" do
    assert_difference "@user.tasks.count", 1 do
      post tasks_url, params: { task: { title: "Купить билеты" } }
    end

    task = @user.tasks.order(:created_at).last
    assert_equal "Купить билеты", task.title
    assert_equal "user", task.owner_type
    assert_equal "inbox", task.status
    assert_nil task.deleted_at
    assert_redirected_to calendar_events_path
    follow_redirect!
    assert_select "turbo-frame#task_lane [data-task-notice]", text: /Задача добавлена/
  end

  test "missing task payload returns the validation frame instead of a request error" do
    assert_no_difference "Task.count" do
      post tasks_url
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#task_lane"
    assert_select "[data-task-errors]"
  end

  test "malformed task payloads return validation instead of raising" do
    [ "строка", [ "массив" ] ].each do |payload|
      assert_no_difference "Task.count" do
        post tasks_url, params: { task: payload }
      end

      assert_response :unprocessable_entity
      assert_select "turbo-frame#task_lane"
    end
  end

  test "accepts the optional next_action, estimate_minutes and due_on fields" do
    post tasks_url, params: {
      task: {
        title: "Подготовить презентацию",
        next_action: "Набросать структуру",
        estimate_minutes: 45,
        due_on: "2026-08-05"
      }
    }

    task = @user.tasks.order(:created_at).last
    assert_equal "Набросать структуру", task.next_action
    assert_equal 45, task.estimate_minutes
    assert_equal Date.new(2026, 8, 5), task.due_on
  end

  test "updates an own unscheduled task and preserves calendar context" do
    task = tasks(:inbox_task)

    patch task_url(task), params: {
      task: {
        title: "Собрать свежие материалы",
        next_action: "Открыть папку исследований",
        estimate_minutes: 40,
        due_on: "2026-08-07",
        lock_version: task.lock_version
      },
      view: "week",
      date: "2026-08-03"
    }

    assert_redirected_to calendar_events_path(view: "week", date: "2026-08-03")
    task.reload
    assert_equal "Собрать свежие материалы", task.title
    assert_equal "Открыть папку исследований", task.next_action
    assert_equal 40, task.estimate_minutes
    assert_equal Date.new(2026, 8, 7), task.due_on
  end

  test "stale edit returns a visible conflict and changes nothing" do
    task = tasks(:inbox_task)
    stale_version = task.lock_version
    task.update!(title: "Свежая версия на сервере")

    patch task_url(task), params: {
      task: {
        title: "Мой устаревший ввод",
        next_action: "Не терять этот текст",
        lock_version: stale_version
      }
    }

    assert_response :conflict
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(task)}"
    assert_match "Свежая версия на сервере", response.body
    assert_match "Мой устаревший ввод", response.body
    assert_equal "Свежая версия на сервере", task.reload.title
  end

  test "missing or malformed lock versions cannot write" do
    [ nil, "abc", 999, ((2**63) - 1).to_s, "9" * 30 ].each do |submitted_lock|
      task = @user.tasks.create!(title: "Исходный текст", owner_type: "user", status: "inbox")
      payload = { title: "Нельзя записать" }
      payload[:lock_version] = submitted_lock unless submitted_lock.nil?

      patch task_url(task), params: { task: payload }

      assert_response :conflict
      assert_equal "Исходный текст", task.reload.title
    end
  end

  test "largest safe task lock increments once and signed max is then rejected" do
    task = @user.tasks.create!(title: "На границе", owner_type: "user", status: "inbox")
    largest_safe = (2**63) - 2
    task.update_column(:lock_version, largest_safe)

    patch task_url(task), params: { task: { title: "Последняя безопасная запись", lock_version: largest_safe } }
    assert_response :redirect
    assert_equal "Последняя безопасная запись", task.reload.title
    assert_equal (2**63) - 1, task.lock_version

    patch task_url(task), params: { task: { title: "Переполнение", lock_version: task.lock_version } }
    assert_response :conflict
    assert_equal "Последняя безопасная запись", task.reload.title
  end

  test "invalid edit returns the task frame and preserves submitted values" do
    task = tasks(:inbox_task)

    patch task_url(task), params: {
      task: {
        title: "",
        next_action: "Сохранить незаконченный ввод",
        estimate_minutes: 35,
        due_on: "2026-08-08",
        lock_version: task.lock_version
      }
    }

    assert_response :unprocessable_entity
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(task)}"
    assert_select "input[value='Сохранить незаконченный ввод']"
    assert_select "input[value='35']"
    assert_equal "Собрать материалы для отчёта", task.reload.title
  end

  test "completes an unscheduled task without deleting it" do
    task = tasks(:next_task)

    assert_no_difference "Task.count" do
      patch complete_task_url(task), params: { task: { lock_version: task.lock_version } }
    end

    assert_redirected_to calendar_events_path
    task.reload
    assert_equal "completed", task.status
    assert_not_nil task.completed_at
    assert_nil task.deleted_at
  end

  test "turbo completion refreshes only task items so the quick-add draft survives" do
    task = tasks(:next_task)

    patch complete_task_url(task),
          params: { task: { lock_version: task.lock_version } },
          headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(task) }

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='task_lane_items']"
    assert_select "turbo-stream[action='update'][target='task_lane_count']"
    assert_select "turbo-stream[action='replace'][target='task_lane_feedback']", text: /Задача завершена/
    assert_no_match task.title, response.body
  end

  test "turbo drop refreshes task items and shows feedback" do
    task = tasks(:inbox_task)

    patch drop_task_url(task),
          params: { task: { lock_version: task.lock_version, drop_reason: "Не нужно" } },
          headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(task) }

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='task_lane_items']"
    assert_select "turbo-stream[action='update'][target='task_lane_count']"
    assert_select "turbo-stream[action='replace'][target='task_lane_feedback']", text: /Задача убрана/
    assert_no_match task.title, response.body
  end

  test "drops an unscheduled task with an optional reason without deleting it" do
    task = tasks(:inbox_task)

    assert_no_difference "Task.count" do
      patch drop_task_url(task), params: {
        task: { lock_version: task.lock_version, drop_reason: "Больше не актуально" }
      }
    end

    assert_redirected_to calendar_events_path
    task.reload
    assert_equal "dropped", task.status
    assert_equal "Больше не актуально", task.drop_reason
    assert_not_nil task.dropped_at
    assert_nil task.deleted_at
  end

  test "scheduled tasks cannot be completed or dropped through the unscheduled lane" do
    [ complete_task_url(tasks(:scheduled_task)), drop_task_url(tasks(:scheduled_task)) ].each do |url|
      task = tasks(:scheduled_task)
      patch url, params: { task: { lock_version: task.lock_version, drop_reason: "forged" } }

      assert_response :not_found
      assert_equal "scheduled", task.reload.status
      assert_nil task.completed_at
      assert_nil task.dropped_at
    end
  end

  test "mutations cannot reach another user's or soft-deleted task" do
    other_task = tasks(:other_user_task)
    deleted_task = tasks(:deleted_task)

    [
      [ task_url(other_task), { task: { title: "Чужое", lock_version: other_task.lock_version } } ],
      [ complete_task_url(other_task), { task: { lock_version: other_task.lock_version } } ],
      [ drop_task_url(other_task), { task: { lock_version: other_task.lock_version } } ],
      [ task_url(deleted_task), { task: { title: "Оживить", lock_version: deleted_task.lock_version } } ],
      [ complete_task_url(deleted_task), { task: { lock_version: deleted_task.lock_version } } ],
      [ drop_task_url(deleted_task), { task: { lock_version: deleted_task.lock_version } } ]
    ].each do |url, payload|
      patch url, params: payload
      assert_response :not_found
    end

    assert_equal "Чужая задача", other_task.reload.title
    assert_not_nil deleted_task.reload.deleted_at
  end

  test "edit ignores ownership and lifecycle fields" do
    task = tasks(:inbox_task)
    other_user = users(:moscow_user)

    patch task_url(task), params: {
      task: {
        title: "Разрешённое изменение",
        user_id: other_user.id,
        owner_type: "assistant",
        status: "completed",
        completed_at: Time.current,
        deleted_at: Time.current,
        lock_version: task.lock_version
      }
    }

    task.reload
    assert_equal "Разрешённое изменение", task.title
    assert_equal @user.id, task.user_id
    assert_equal "user", task.owner_type
    assert_equal "inbox", task.status
    assert_nil task.completed_at
    assert_nil task.deleted_at
  end

  test "overlong drop reason returns the task frame and keeps the task open" do
    task = tasks(:inbox_task)

    patch drop_task_url(task), params: {
      task: { lock_version: task.lock_version, drop_reason: "я" * 501 }
    }

    assert_response :unprocessable_entity
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(task)}"
    assert_select "[data-task-edit-errors]"
    assert_select "details.task-card-dropper[open]"
    assert_select "details.task-card-editor[open]", count: 0
    assert_equal "inbox", task.reload.status
    assert_nil task.dropped_at
  end

  test "stale complete and drop return visible conflicts and change nothing" do
    [ :complete, :drop ].each do |action|
      task = @user.tasks.create!(title: "Конкурентная #{action}", owner_type: "user", status: "inbox")
      stale_version = task.lock_version
      task.update!(title: "Свежая #{action}")
      url = action == :complete ? complete_task_url(task) : drop_task_url(task)

      patch url, params: { task: { lock_version: stale_version, drop_reason: "Устаревшая причина" } }

      assert_response :conflict
      assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(task)}"
      assert_select "[data-task-conflict]"
      assert_equal "inbox", task.reload.status
    end
  end

  test "a stale conflict can be retried with the fresh lock version from the response" do
    task = tasks(:inbox_task)
    stale_version = task.lock_version
    task.update!(title: "Серверная версия")

    patch task_url(task), params: { task: { title: "Мой вариант", lock_version: stale_version } }
    assert_response :conflict
    fresh_version = css_select("input[name='task[lock_version]']").first["value"]

    patch task_url(task), params: { task: { title: "Мой вариант", lock_version: fresh_version } }

    assert_redirected_to calendar_events_path
    assert_equal "Мой вариант", task.reload.title
  end

  test "terminal cross-tab state changes return conflicts instead of frame 404s" do
    completed = @user.tasks.create!(title: "Уже завершена", owner_type: "user", status: "inbox")
    stale_completed = completed.lock_version
    completed.update!(status: "completed", completed_at: Time.current)

    patch task_url(completed), params: { task: { title: "Устаревшая правка", lock_version: stale_completed } }
    assert_response :conflict
    assert_select "[data-task-conflict]"

    dropped = @user.tasks.create!(title: "Уже убрана", owner_type: "user", status: "inbox")
    stale_dropped = dropped.lock_version
    dropped.update!(status: "dropped", dropped_at: Time.current)

    patch complete_task_url(dropped), params: { task: { lock_version: stale_dropped } }
    assert_response :conflict
    assert_select "[data-task-conflict]"

    assert_equal "completed", completed.reload.status
    assert_equal "dropped", dropped.reload.status
  end

  test "idempotent terminal requests still require a valid current lock version" do
    task = @user.tasks.create!(title: "Уже готово", owner_type: "user", status: "completed", completed_at: Time.current)

    patch complete_task_url(task), params: { task: { lock_version: "abc" } }

    assert_response :conflict
    assert_select "[data-task-conflict]"
    assert_equal "completed", task.reload.status
  end

  test "repeating an already completed or dropped transition is idempotent" do
    completed = @user.tasks.create!(title: "Завершить один раз", owner_type: "user", status: "inbox")
    patch complete_task_url(completed), params: { task: { lock_version: completed.lock_version } }
    first_completed_at = completed.reload.completed_at
    patch complete_task_url(completed), params: { task: { lock_version: completed.lock_version } }
    assert_redirected_to calendar_events_path
    assert_equal first_completed_at, completed.reload.completed_at

    dropped = @user.tasks.create!(title: "Убрать один раз", owner_type: "user", status: "inbox")
    patch drop_task_url(dropped), params: { task: { lock_version: dropped.lock_version, drop_reason: "Первая причина" } }
    first_dropped_at = dropped.reload.dropped_at
    patch drop_task_url(dropped), params: { task: { lock_version: dropped.lock_version, drop_reason: "Не перезаписывать" } }
    assert_redirected_to calendar_events_path
    assert_equal first_dropped_at, dropped.reload.dropped_at
    assert_equal "Первая причина", dropped.drop_reason
  end

  test "forces ownership, owner_type and status regardless of submitted params" do
    other_user = users(:moscow_user)

    assert_no_difference "other_user.tasks.count" do
      post tasks_url, params: {
        task: {
          title: "Подменённая задача",
          user_id: other_user.id,
          owner_type: "assistant",
          status: "scheduled",
          deleted_at: 1.day.ago
        }
      }
    end

    task = @user.tasks.order(:created_at).last
    assert_equal @user.id, task.user_id
    assert_equal "user", task.owner_type
    assert_equal "inbox", task.status
    assert_nil task.deleted_at
  end

  test "redirects back to the calendar preserving safe view and date params" do
    post tasks_url, params: { task: { title: "Задача из недели" }, view: "week", date: "2026-08-03" }

    assert_redirected_to calendar_events_path(view: "week", date: "2026-08-03")
  end

  test "drops unsafe view and date params on redirect" do
    post tasks_url, params: { task: { title: "Задача с мусором" }, view: "timeline", date: "not-a-date" }

    assert_redirected_to calendar_events_path
  end

  test "invalid task returns 422 with visible errors inside the task lane frame" do
    assert_no_difference "Task.count" do
      post tasks_url, params: { task: { title: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "html"
    assert_select "link[rel='stylesheet']"
    assert_select "turbo-frame#task_lane"
    assert_select "[data-task-errors]"
    assert_select "[data-task-form]", count: 1
  end

  test "uncastable optional fields return visible validation errors" do
    [ { estimate_minutes: "abc" }, { due_on: "not-a-date" } ].each do |invalid_optional|
      assert_no_difference "Task.count" do
        post tasks_url, params: { task: { title: "Не терять ввод" }.merge(invalid_optional) }
      end

      assert_response :unprocessable_entity
      assert_select "[data-task-errors]"
    end
  end

  test "invalid response preserves safe calendar context" do
    post tasks_url, params: { task: { title: "" }, view: "week", date: "2026-08-03" }

    assert_response :unprocessable_entity
    assert_select "input[name='view'][value='week']"
    assert_select "input[name='date'][value='2026-08-03']"
  end

  test "the re-rendered lane never leaks another user's or hidden tasks" do
    post tasks_url, params: { task: { title: "" } }

    assert_response :unprocessable_entity
    assert_select "[data-task-card]", text: /Собрать материалы для отчёта/
    assert_no_match "Чужая задача", response.body
    assert_no_match "Удалённая задача", response.body
    assert_no_match "Уже стоит в календаре", response.body
  end

  test "invalid lane is scoped to the currently authenticated second user" do
    reset!
    other_user = users(:moscow_user)
    previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = other_user.telegram_id.to_s
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(other_user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    assert_response :success

    post tasks_url, params: { task: { title: "" } }

    assert_response :unprocessable_entity
    assert_select "[data-task-card]", text: /Чужая задача/
    assert_no_match "Собрать материалы для отчёта", response.body
  ensure
    ENV["ECHO_OWNER_TELEGRAM_ID"] = previous_owner_id
  end
end

require "test_helper"

class TaskStepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    @task = @user.tasks.create!(title: "Сложная задача", status: "someday")
  end

  test "append toggle and remove are ordered and each bumps the parent revision" do
    version = @task.lock_version
    assert_difference "TaskStep.count", 1 do
      post task_task_steps_path(@task), params: { task: { lock_version: version }, task_step: { text: "Первый шаг" } }
    end
    step = @task.task_steps.first
    assert_equal 0, step.position
    assert_equal version + 1, @task.reload.lock_version

    version = @task.lock_version
    patch toggle_task_task_step_path(@task, step), params: { task: { lock_version: version } }
    assert step.reload.completed_at.present?
    assert_equal version + 1, @task.reload.lock_version

    version = @task.lock_version
    assert_difference "TaskStep.count", -1 do
      delete task_task_step_path(@task, step), params: { task: { lock_version: version } }
    end
    assert_equal version + 1, @task.reload.lock_version
  end

  test "stale child mutation conflicts without changing child or parent" do
    step = @task.task_steps.create!(text: "Не менять", position: 0)
    stale = @task.lock_version
    @task.update!(title: "Свежая версия")
    fresh = @task.reload.lock_version

    patch toggle_task_task_step_path(@task, step), params: { task: { lock_version: stale } }

    assert_response :see_other
    assert_redirected_to tasks_path(status: "someday")
    follow_redirect!
    assert_select "[role='alert']", text: /изменил/
    assert_nil step.reload.completed_at
    assert_equal fresh, @task.reload.lock_version
  end

  test "foreign task and mismatched child are unreachable" do
    foreign_task = users(:moscow_user).tasks.create!(title: "Чужая")
    foreign_step = foreign_task.task_steps.create!(text: "Чужой шаг", position: 0)
    own_step = @task.task_steps.create!(text: "Свой шаг", position: 0)

    post task_task_steps_path(foreign_task), params: { task: { lock_version: foreign_task.lock_version }, task_step: { text: "Взлом" } }
    assert_response :not_found

    patch toggle_task_task_step_path(@task, foreign_step), params: { task: { lock_version: @task.lock_version } }
    assert_response :not_found
    assert_nil foreign_step.reload.completed_at
    assert_nil own_step.reload.completed_at
  end

  test "terminal tasks reject every child mutation" do
    step = @task.task_steps.create!(text: "Шаг", position: 0)
    @task.update!(status: "completed", completed_at: Time.current)

    post task_task_steps_path(@task), params: { task: { lock_version: @task.lock_version }, task_step: { text: "Новый" } }
    assert_response :not_found
    patch toggle_task_task_step_path(@task, step), params: { task: { lock_version: @task.lock_version } }
    assert_response :not_found
    delete task_task_step_path(@task, step), params: { task: { lock_version: @task.lock_version } }
    assert_response :not_found
  end

  test "checklist change makes an already-open completion request stale" do
    @task.update!(status: "next")
    old_completion_version = @task.lock_version
    post task_task_steps_path(@task), params: { task: { lock_version: old_completion_version }, task_step: { text: "Новый критерий" } }

    patch complete_task_path(@task), params: { task: { lock_version: old_completion_version } }

    assert_response :conflict
    assert_equal "next", @task.reload.status
  end

  test "largest safe parent lock increments once and signed max blocks checklist mutation" do
    largest_safe = (2**63) - 2
    @task.update_column(:lock_version, largest_safe)

    assert_difference "TaskStep.count", 1 do
      post task_task_steps_path(@task), params: { task: { lock_version: largest_safe }, task_step: { text: "Последний безопасный шаг" } }
    end
    assert_equal (2**63) - 1, @task.reload.lock_version

    assert_no_difference "TaskStep.count" do
      post task_task_steps_path(@task), params: { task: { lock_version: @task.lock_version }, task_step: { text: "Переполнение" } }
    end
    assert_response :see_other
    assert_equal (2**63) - 1, @task.reload.lock_version
  end
end

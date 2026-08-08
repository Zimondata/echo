require "test_helper"

class TaskCaptureAndMetadataTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    @project = @user.projects.create!(name: "Echo")
  end

  test "tasks and planner use the same closed progressive quick capture contract" do
    get tasks_path
    assert_capture_contract

    get calendar_events_path(view: "week", date: "2026-08-03")
    assert_capture_contract
  end

  test "quick capture accepts the same optional metadata but never checklist or status" do
    post tasks_path, params: {
      return_to: "tasks",
      task: {
        title: "Зафиксировать",
        next_action: "Открыть документ",
        estimate_minutes: 25,
        due_on: "2026-08-12",
        project_id: @project.id,
        description: "Контекст",
        status: "completed",
        task_steps_attributes: { "0" => { text: "Подмена" } }
      }
    }

    task = @user.tasks.last
    assert_equal "inbox", task.status
    assert_equal @project, task.project
    assert_equal "Контекст", task.description
    assert_empty task.task_steps
  end

  test "metadata edit works for every nonterminal state and ignores lifecycle fields" do
    %w[inbox next scheduled waiting someday].each do |status|
      task = @user.tasks.create!(title: "До #{status}", status: status)

      patch task_path(task), params: {
        return_to: "tasks",
        status: status,
        task: {
          title: "После #{status}", description: "Описание", next_action: "Шаг",
          estimate_minutes: 15, due_on: "2026-08-15", project_id: @project.id,
          status: "dropped", lock_version: task.lock_version
        }
      }

      assert_redirected_to tasks_path(status: status)
      task.reload
      assert_equal "После #{status}", task.title
      assert_equal "Описание", task.description
      assert_equal status, task.status
      assert_equal @project, task.project
    end
  end

  test "task details expose metadata and checklist without a status field" do
    task = @user.tasks.create!(title: "Раскрыть", status: "someday", project: @project, description: "Контекст")
    task.task_steps.create!(text: "Первый", position: 0, completed_at: Time.current)
    task.task_steps.create!(text: "Второй", position: 1)

    get tasks_path(status: "someday")

    assert_select "[data-task-id='#{task.id}']" do
      assert_select "[data-checklist-count]", text: "1/2"
      assert_select "details[data-task-details]:not([open])" do
        assert_select "form[action='#{task_path(task)}'] input[name='task[lock_version]']"
        assert_select "textarea[name='task[description]']", text: "Контекст"
        assert_select "select[name='task[project_id]']"
        assert_select "select[name='task[status]']", count: 0
        assert_select "form[action='#{task_task_steps_path(task)}'] input[name='task_step[text]']"
        assert_select "form[action='#{toggle_task_task_step_path(task, task.task_steps.first)}']"
        assert_select "form[action='#{task_task_step_path(task, task.task_steps.last)}'] input[name='_method'][value='delete']"
      end
    end
  end

  test "waiting and scheduled rows do not advertise unsupported lifecycle mutations" do
    waiting = @user.tasks.create!(title: "Жду ответа", status: "waiting")
    scheduled = @user.tasks.create!(title: "Уже в плане", status: "scheduled")
    next_task = @user.tasks.create!(title: "Есть критерий", status: "next")
    next_task.task_steps.create!(text: "Незавершённый шаг", position: 0)

    get tasks_path(status: "next")
    assert_select "[data-task-id='#{next_task.id}'] form[action='#{complete_task_path(next_task)}'][data-turbo-confirm]"

    get tasks_path(status: "waiting")
    assert_select "[data-task-id='#{waiting.id}']" do
      assert_select "form[action='#{complete_task_path(waiting)}']", count: 0
      assert_select "form[action='#{drop_task_path(waiting)}']", count: 0
    end

    get tasks_path(status: "scheduled")
    assert_select "[data-task-id='#{scheduled.id}']" do
      assert_select "form[action='#{complete_task_path(scheduled)}']", count: 0
      assert_select "form[action='#{drop_task_path(scheduled)}']", count: 0
      assert_select "a[href*='/calendar_events']", text: /Открыть в плане/
    end
  end

  test "terminal metadata edit conflicts and stale nonterminal edit conflicts" do
    terminal = @user.tasks.create!(title: "Закрыта", status: "completed", completed_at: Time.current)
    patch task_path(terminal), params: { task: { title: "Не менять", lock_version: terminal.lock_version } }
    assert_response :conflict
    assert_equal "Закрыта", terminal.reload.title

    task = @user.tasks.create!(title: "Старая", status: "waiting")
    stale = task.lock_version
    task.update!(title: "Свежая")
    patch task_path(task), params: { return_to: "tasks", status: "waiting", task: { title: "Устаревшая", lock_version: stale } }
    assert_response :conflict
    assert_select "h1", text: "Задачи"
    assert_match(/изменена в другой вкладке/i, response.body)
    assert_match(/Свежая/, response.body)
    assert_equal "Свежая", task.reload.title
  end

  private

  def assert_capture_contract
    assert_select "form[data-shared-quick-capture]", count: 1 do
      assert_select ".task-form-row input[name='task[title]']", count: 1
      assert_select ".task-form-row input[type='submit']", count: 1
      assert_select ".task-form-row input[name='task[next_action]']", count: 0
      assert_select "details[data-quick-capture-details]:not([open])", count: 1 do
        assert_select "input[name='task[next_action]']"
        assert_select "input[name='task[estimate_minutes]']"
        assert_select "input[name='task[due_on]']"
        assert_select "select[name='task[project_id]']"
      end
    end
  end
end

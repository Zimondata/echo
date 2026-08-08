require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
  end

  test "project workspace shows only its active tasks grouped by lifecycle" do
    project = @user.projects.create!(name: "Нейросамурай")
    next_task = @user.tasks.create!(title: "Следующий шаг", status: "next", project: project)
    scheduled_task = @user.tasks.create!(title: "В плане", status: "scheduled", project: project)
    waiting_task = @user.tasks.create!(title: "Жду ответ", status: "waiting", project: project)
    someday_task = @user.tasks.create!(title: "На потом", status: "someday", project: project)
    completed_task = @user.tasks.create!(title: "Готово", status: "completed", project: project, completed_at: Time.current)
    dropped_task = @user.tasks.create!(title: "Убрано", status: "dropped", project: project, dropped_at: Time.current)
    deleted_task = @user.tasks.create!(title: "Удалённая", status: "next", project: project, deleted_at: Time.current)
    other_project = @user.projects.create!(name: "Другой")
    other_task = @user.tasks.create!(title: "Чужой проект", status: "next", project: other_project)

    get project_path(project)

    assert_response :success
    assert_select "h1", text: "Нейросамурай"
    assert_select "[data-project-status='next'] [data-task-id='#{next_task.id}']"
    assert_select "[data-project-status='scheduled'] [data-task-id='#{scheduled_task.id}']"
    assert_select "[data-project-status='waiting'] [data-task-id='#{waiting_task.id}']"
    assert_select "[data-project-status='someday'] [data-task-id='#{someday_task.id}']"
    assert_select "details[data-project-status='completed'] [data-task-id='#{completed_task.id}']"
    assert_select "details[data-project-status='dropped'] [data-task-id='#{dropped_task.id}']"
    assert_select "[data-task-id='#{deleted_task.id}']", count: 0
    assert_select "[data-task-id='#{other_task.id}']", count: 0
    assert_select "[data-project-workspace] [data-project-label]", count: 0
    assert_select "form[action='#{tasks_path}'] select[name='task[project_id]'] option[selected][value='#{project.id}']"
  end

  test "project capture creates an assigned task and returns to the workspace" do
    project = @user.projects.create!(name: "Нейросамурай")

    assert_difference "project.tasks.count", 1 do
      post tasks_path, params: {
        return_to: "project",
        task: { title: "Собрать план запуска", project_id: project.id }
      }
    end

    assert_redirected_to project_path(project)
    assert_equal "Собрать план запуска", project.tasks.order(:id).last.title
  end

  test "invalid project capture stays in the project workspace" do
    project = @user.projects.create!(name: "Нейросамурай")

    assert_no_difference "project.tasks.count" do
      post tasks_path, params: {
        return_to: "project",
        task: { title: " ", description: "Сохранить контекст", next_action: "Сохранить шаг", project_id: project.id }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h1", text: "Нейросамурай"
    assert_select "[data-task-errors]"
    assert_select "textarea[name='task[description]']", text: "Сохранить контекст"
    assert_select "input[name='task[next_action]'][value='Сохранить шаг']"
    assert_select "select[name='task[project_id]'] option[selected][value='#{project.id}']"
  end

  test "project capture rejects archived and foreign projects" do
    archived = @user.projects.create!(name: "Архив")
    archived.archive!(archived.lock_version)
    foreign = users(:moscow_user).projects.create!(name: "Чужой")

    [ archived, foreign ].each do |project|
      assert_no_difference "Task.count" do
        post tasks_path, params: {
          return_to: "project",
          task: { title: "Запрещено", project_id: project.id }
        }
      end
      assert_response :not_found
    end
  end

  test "project index counts only current active tasks" do
    own = @user.projects.create!(name: "Счётчик")
    @user.tasks.create!(title: "Видимая", status: "next", project: own)
    @user.tasks.create!(title: "Удалённая", status: "next", project: own, deleted_at: Time.current)
    foreign_project = users(:moscow_user).projects.create!(name: "Чужой счётчик")
    users(:moscow_user).tasks.create!(title: "Чужая", status: "next", project: foreign_project)

    get projects_path

    assert_response :success
    assert_select "[data-project-id='#{own.id}'] .echo-section-copy", text: "1 задача"
    assert_select "[data-project-id='#{foreign_project.id}']", count: 0
  end

  test "archived and foreign project workspace boundaries fail closed" do
    archived = @user.projects.create!(name: "Архив")
    archived.archive!(archived.lock_version)
    foreign = users(:moscow_user).projects.create!(name: "Чужой")

    get project_path(archived)
    assert_response :success
    assert_select "form[action='#{tasks_path}']", count: 0

    get project_path(foreign)
    assert_response :not_found
  end

  test "tasks links to the minimal create rename and archive project surface" do
    get tasks_path

    assert_response :success
    assert_select "a[href='#{projects_path}']", text: "Проекты"

    get projects_path
    assert_select "form[action='#{projects_path}'] input[name='project[name]']"
    assert_no_match(/прогресс|аналитика|дедлайн/i, response.body)
  end

  test "creates own project and archives it with strict optimistic locking" do
    assert_difference "@user.projects.count", 1 do
      post projects_path, params: { project: { name: "Новый проект", user_id: users(:moscow_user).id } }
    end
    project = @user.projects.last
    assert_equal @user, project.user

    patch archive_project_path(project), params: { project: { lock_version: project.lock_version } }
    assert_redirected_to projects_path
    assert project.reload.archived?

    stale = project.lock_version - 1
    patch archive_project_path(project), params: { project: { lock_version: stale } }
    assert_response :conflict
  end

  test "owner can rename active and archived projects with optimistic locking" do
    project = @user.projects.create!(name: "Опечатка")

    patch project_path(project), params: { project: { name: "Исправлено", lock_version: project.lock_version } }
    assert_redirected_to projects_path
    assert_equal "Исправлено", project.reload.name

    project.archive!(project.lock_version)
    patch project_path(project), params: { project: { name: "Исправлено в архиве", lock_version: project.lock_version } }
    assert_redirected_to projects_path
    assert_equal "Исправлено в архиве", project.reload.name
  end

  test "project rename rejects stale and foreign revisions" do
    project = @user.projects.create!(name: "Живое имя")
    stale = project.lock_version
    project.update!(name: "Свежее имя")

    patch project_path(project), params: { project: { name: "Устаревшее имя", lock_version: stale } }
    assert_response :conflict
    assert_select "h1", text: "Проекты"
    assert_select "[role='alert']", text: /изменился/
    assert_equal "Свежее имя", project.reload.name

    [ ((2**63) - 1).to_s, "9" * 200, "-1", "abc", "" ].each do |invalid_revision|
      patch project_path(project), params: { project: { name: "За пределами", lock_version: invalid_revision } }
      assert_response :conflict
      assert_equal "Свежее имя", project.reload.name
    end

    foreign = users(:moscow_user).projects.create!(name: "Чужой")
    patch project_path(foreign), params: { project: { name: "Захват", lock_version: foreign.lock_version } }
    assert_response :not_found
    assert_equal "Чужой", foreign.reload.name
  end

  test "project management renders rename controls" do
    active = @user.projects.create!(name: "Активный")
    archived = @user.projects.create!(name: "Архивный")
    archived.archive!(archived.lock_version)

    get projects_path

    assert_response :success
    assert_select "form[action='#{project_path(active)}'] input[name='project[name]']"
    assert_select "form[action='#{project_path(archived)}'] input[name='project[name]']"
  end

  test "cannot archive a foreign project" do
    foreign = users(:moscow_user).projects.create!(name: "Чужой")

    patch archive_project_path(foreign), params: { project: { lock_version: foreign.lock_version } }

    assert_response :not_found
    assert foreign.reload.active?
  end

  test "task assignment resolves only an active own project" do
    own = @user.projects.create!(name: "Свой")
    archived = @user.projects.create!(name: "Архив")
    archived.update!(archived_at: Time.current)
    foreign = users(:moscow_user).projects.create!(name: "Чужой")

    post tasks_path, params: { return_to: "tasks", task: { title: "Своя", project_id: own.id } }
    assert_equal own, @user.tasks.last.project

    [ archived, foreign ].each do |project|
      assert_no_difference "@user.tasks.count" do
        post tasks_path, params: { return_to: "tasks", task: { title: "Запрещено", project_id: project.id } }
      end
      assert_response :not_found
    end
  end
end

require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
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

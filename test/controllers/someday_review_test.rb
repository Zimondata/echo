require "test_helper"

class SomedayReviewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
  end

  test "moves only an own fresh someday task to next" do
    task = @user.tasks.create!(title: "Выбрать следующим", status: "someday")

    patch move_to_next_task_path(task), params: { task: { lock_version: task.lock_version } }

    assert_redirected_to tasks_path(status: "someday")
    assert_equal "next", task.reload.status
  end

  test "stale someday move and drop conflict without mutation" do
    %i[move drop].each do |action|
      task = @user.tasks.create!(title: "Устаревшая #{action}", status: "someday")
      stale = task.lock_version
      task.update!(title: "Свежая")
      path = action == :move ? move_to_next_task_path(task) : drop_from_someday_task_path(task)

      patch path, params: { return_to: "tasks", status: "someday", task: { lock_version: stale, drop_reason: "Убрать" } }

      assert_response :conflict
      assert_select "h1", text: "Задачи"
      assert_select "[role='alert']", text: /изменена в другой вкладке/
      assert_equal "someday", task.reload.status
    end
  end

  test "scheduled waiting terminal foreign and soft-deleted tasks cannot move or drop through someday review" do
    candidates = %w[scheduled waiting completed dropped].map do |status|
      @user.tasks.create!(title: status, status: status)
    end
    foreign = users(:moscow_user).tasks.create!(title: "foreign", status: "someday")
    deleted = @user.tasks.create!(title: "deleted", status: "someday", deleted_at: Time.current)

    (candidates + [ foreign, deleted ]).each do |task|
      [ move_to_next_task_path(task), drop_from_someday_task_path(task) ].each do |path|
        patch path, params: { task: { lock_version: task.lock_version, drop_reason: "forged" } }
        assert_response :not_found
      end
    end
  end

  test "drops an own fresh someday task explicitly" do
    task = @user.tasks.create!(title: "Убрать когда-нибудь", status: "someday")

    patch drop_from_someday_task_path(task), params: { return_to: "tasks", status: "someday", task: { lock_version: task.lock_version, drop_reason: "Не нужно" } }

    assert_redirected_to tasks_path(status: "someday")
    assert_equal "dropped", task.reload.status
  end

  test "someday view groups inside project sections and has no keep mutation" do
    alpha = @user.projects.create!(name: "Альфа")
    beta = @user.projects.create!(name: "Бета")
    @user.tasks.create!(title: "Альфа-задача", status: "someday", project: alpha)
    @user.tasks.create!(title: "Бета-задача", status: "someday", project: beta)
    @user.tasks.create!(title: "Свободная задача", status: "someday")

    get tasks_path(status: "someday")

    assert_select "[data-project-section='#{alpha.id}']" do
      assert_select "h2", text: "Альфа"
      assert_select "[data-task-id]", text: /Альфа-задача/
      assert_select "[data-task-id]", text: /Бета-задача/, count: 0
    end
    assert_select "[data-project-section='none']", text: /Свободная задача/
    assert_select "form[action*='move_to_next']", text: /В следующие/, minimum: 1
    assert_select "button", text: /Оставить/, count: 0
    assert_match(/оставить без изменений/i, response.body)
  end
end

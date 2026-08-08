require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
  end

  test "is a lightweight ordered task classifier" do
    project = @user.projects.create!(name: "  Echo launch  ", position: 2)

    assert_equal "Echo launch", project.name
    assert project.active?
    assert_equal 0, project.lock_version
    assert_equal %w[archived_at created_at id lock_version name position updated_at user_id], project.attributes.keys.sort
  end

  test "task rejects a project owned by somebody else" do
    foreign = users(:moscow_user).projects.create!(name: "Чужой")
    task = @user.tasks.new(title: "Нельзя присвоить", project: foreign)

    assert_not task.valid?
    assert_includes task.errors.attribute_names, :project
  end

  test "archived project remains on existing task but cannot be newly assigned" do
    project = @user.projects.create!(name: "Старый")
    task = @user.tasks.create!(title: "Контекст сохранён", project: project)

    project.archive!(project.lock_version)

    assert_equal project, task.reload.project
    task.update!(title: "Контекст всё ещё сохранён")
    assert_equal project, task.reload.project

    new_task = @user.tasks.new(title: "Позднее назначение", project: project)
    assert_not new_task.valid?
    assert_includes new_task.errors.attribute_names, :project
  end
end

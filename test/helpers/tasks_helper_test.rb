require "test_helper"

class TasksHelperTest < ActionView::TestCase
  test "extracts a known workstream prefix without changing the stored title" do
    task = Task.new(title: "Рост · Запустить SEO")

    assert_equal "Рост", task_workstream(task)
    assert_equal "Запустить SEO", task_display_title(task)
    assert_equal "Рост · Запустить SEO", task.title
  end

  test "keeps an ordinary title intact" do
    task = Task.new(title: "Купить билеты")

    assert_nil task_workstream(task)
    assert_equal "Купить билеты", task_display_title(task)
  end

  test "does not treat an unknown prefix as a workstream" do
    task = Task.new(title: "Важное · Купить билеты")

    assert_nil task_workstream(task)
    assert_equal "Важное · Купить билеты", task_display_title(task)
  end
end

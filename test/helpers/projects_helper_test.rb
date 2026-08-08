require "test_helper"

class ProjectsHelperTest < ActionView::TestCase
  test "formats Russian task counts" do
    assert_equal "0 задач", task_count_label(0)
    assert_equal "1 задача", task_count_label(1)
    assert_equal "2 задачи", task_count_label(2)
    assert_equal "5 задач", task_count_label(5)
    assert_equal "11 задач", task_count_label(11)
    assert_equal "21 задача", task_count_label(21)
    assert_equal "24 задачи", task_count_label(24)
  end
end

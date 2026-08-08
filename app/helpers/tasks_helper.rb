module TasksHelper
  WORKSTREAMS = {
    "Продукт" => "product",
    "Платформа" => "platform",
    "Проверка" => "verification",
    "Контент" => "content",
    "Интеграция" => "integration",
    "Запуск" => "launch",
    "Рост" => "growth",
    "Трафик" => "traffic"
  }.freeze

  def task_workstream(task)
    prefix, separator, = task.title.to_s.partition(" · ")
    prefix if separator.present? && WORKSTREAMS.key?(prefix)
  end

  def task_display_title(task)
    workstream = task_workstream(task)
    return task.title unless workstream

    task.title.to_s.delete_prefix("#{workstream} · ")
  end

  def task_workstream_class(task)
    slug = WORKSTREAMS[task_workstream(task)]
    "echo-badge--workstream-#{slug}" if slug
  end
end

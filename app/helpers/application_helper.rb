module ApplicationHelper
  RUSSIAN_MONTHS_GENITIVE = %w[января февраля марта апреля мая июня июля августа сентября октября ноября декабря].freeze

  def permanent_destinations
    [
      { label: "План", path: calendar_events_path(view: "month"), icon: '<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M7 3v4M17 3v4M3.5 9.5h17"/>' },
      { label: "Задачи", path: tasks_path, icon: '<path d="m5 7 2 2 4-4M5 13l2 2 4-4M13 7h6M13 13h6M5 19h14"/>' },
      { label: "Дневник", path: diary_entries_path, icon: '<path d="M5 4h12a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2V4Z"/><path d="M8 8h8M8 12h8"/>' },
      { label: "Напоминания", path: reminders_path, icon: '<path d="M6 9a6 6 0 0 1 12 0v5l2 3H4l2-3V9Z"/><path d="M10 20h4"/>' },
      { label: "Здоровье", path: health_path, icon: '<path d="M12 20S4 15.5 4 9a4 4 0 0 1 7-2.6A4 4 0 0 1 18 9c0 6.5-6 11-6 11Z"/>' }
    ]
  end

  def russian_date(value)
    date = value.to_date
    "#{date.day} #{RUSSIAN_MONTHS_GENITIVE.fetch(date.month - 1)} #{date.year}"
  end

  def russian_datetime(value, time_zone)
    local = value.in_time_zone(time_zone)
    "#{russian_date(local)}, #{local.strftime('%H:%M')}"
  end

  def rhythm_state_label(state)
    {
      "full" => "полностью",
      "minimum" => "минимум",
      "skipped" => "пропуск",
      "returned" => "вернулся"
    }.fetch(state.to_s, "нет отметки")
  end

  def reminder_priority_label(priority)
    { "high" => "Срочное", "medium" => "Обычное", "low" => "Мягкое" }.fetch(priority.to_s, "Обычное")
  end
end

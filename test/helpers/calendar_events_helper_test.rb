require "test_helper"

class CalendarEventsHelperTest < ActionView::TestCase
  include CalendarEventsHelper

  test "week layout clips a multi-day event to each selected date" do
    zone = Time.find_zone!("Europe/Madrid")
    event = CalendarEvent.new(title: "Длинный выезд", start_time: zone.local(2026, 10, 19, 18), end_time: zone.local(2026, 10, 21, 10), color: "#8B5CF6")

    monday = calendar_week_timeline_layout([ event ], [], Date.new(2026, 10, 19), zone.name).first
    tuesday = calendar_week_timeline_layout([ event ], [], Date.new(2026, 10, 20), zone.name).first
    wednesday = calendar_week_timeline_layout([ event ], [], Date.new(2026, 10, 21), zone.name).first

    assert_includes calendar_week_item_style(monday), "top: 672px"
    assert_includes calendar_week_item_style(monday), "height: 336px"
    assert_equal "18:00–24:00 ↦", calendar_day_item_time(monday)
    assert_includes calendar_week_item_style(tuesday), "top: 0px"
    assert_includes calendar_week_item_style(tuesday), "height: 1008px"
    assert_equal "↤ 06:00–24:00 ↦", calendar_day_item_time(tuesday)
    assert_includes calendar_week_item_style(wednesday), "top: 0px"
    assert_includes calendar_week_item_style(wednesday), "height: 224px"
    assert_equal "↤ 06:00–10:00", calendar_day_item_time(wednesday)
  end

  test "week layout renders an event ending at midnight through 24:00" do
    zone = Time.find_zone!("Europe/Madrid")
    event = CalendarEvent.new(title: "До полуночи", start_time: zone.local(2026, 10, 19, 20), end_time: zone.local(2026, 10, 20, 0), color: "#8B5CF6")

    item = calendar_week_timeline_layout([ event ], [], Date.new(2026, 10, 19), zone.name).first

    assert_includes calendar_week_item_style(item), "top: 784px"
    assert_includes calendar_week_item_style(item), "height: 224px"
    assert_equal "20:00–24:00", calendar_day_item_time(item)
    assert_empty calendar_week_timeline_layout([ event ], [], Date.new(2026, 10, 20), zone.name)
  end

  test "week layout places overlapping events and a task in separate lanes" do
    zone = Time.find_zone!("Europe/Madrid")
    date = Date.new(2026, 10, 19)
    first = CalendarEvent.new(title: "Первое", start_time: zone.local(2026, 10, 19, 10), end_time: zone.local(2026, 10, 19, 12), color: "#8B5CF6")
    second = CalendarEvent.new(title: "Второе", start_time: zone.local(2026, 10, 19, 10, 30), end_time: zone.local(2026, 10, 19, 11, 30), color: "#22C55E")
    task = Task.new(title: "Задача")
    block = TimeBlock.new(task: task, starts_at: zone.local(2026, 10, 19, 10, 45), ends_at: zone.local(2026, 10, 19, 11, 15))

    items = calendar_week_timeline_layout([ first, second ], [ block ], date, zone.name)
    styles = items.map { |item| calendar_week_item_style(item) }

    assert_equal 3, items.size
    assert_equal 3, styles.uniq.size
    assert styles.all? { |style| style.include?("width: calc(33.333%") }
  end

  test "true overlaps keep equal collision lanes" do
    zone = Time.find_zone!("Europe/Madrid")
    date = Date.new(2026, 8, 12)
    first_event = CalendarEvent.new(
      title: "Первое",
      start_time: zone.local(2026, 8, 12, 13, 0),
      end_time: zone.local(2026, 8, 12, 14, 0),
      color: "#6B7280"
    )
    second_event = CalendarEvent.new(
      title: "Второе",
      start_time: zone.local(2026, 8, 12, 13, 30),
      end_time: zone.local(2026, 8, 12, 14, 30),
      color: "#8B5CF6"
    )

    items = calendar_day_timeline_layout([ first_event, second_event ], [], date, zone.name)

    assert_equal 2, items.size
    assert items.all? { |item| calendar_day_item_style(item).include?("width: calc(50.000%") }
  end

  test "adjacent short and long events use duration-weighted collision lanes" do
    zone = Time.find_zone!("Europe/Madrid")
    date = Date.new(2026, 8, 12)
    short_event = CalendarEvent.new(
      title: "Дыхание",
      start_time: zone.local(2026, 8, 12, 13, 10),
      end_time: zone.local(2026, 8, 12, 13, 20),
      color: "#6B7280"
    )
    long_event = CalendarEvent.new(
      title: "Глубокая работа",
      start_time: zone.local(2026, 8, 12, 13, 20),
      end_time: zone.local(2026, 8, 12, 14, 50),
      color: "#8B5CF6"
    )

    short_item, long_item = calendar_day_timeline_layout([ short_event, long_event ], [], date, zone.name)

    short_style = calendar_day_item_style(short_item)
    long_style = calendar_day_item_style(long_item)

    assert_includes short_style, "--desktop-lane-width: 30.000%"
    assert_includes long_style, "--desktop-lane-left: 30.000%"
    assert_includes long_style, "--desktop-lane-width: 70.000%"
    assert_includes short_style, "left: calc(0.000% + 4px)"
    assert_includes short_style, "width: calc(50.000% - 8px)"
    assert_includes long_style, "left: calc(50.000% + 4px)"
    assert_includes long_style, "width: calc(50.000% - 8px)"
  end
end

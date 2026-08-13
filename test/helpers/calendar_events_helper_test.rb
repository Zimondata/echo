require "test_helper"

class CalendarEventsHelperTest < ActionView::TestCase
  include CalendarEventsHelper

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

    assert_includes calendar_day_item_style(short_item), "width: calc(30.000%"
    assert_includes calendar_day_item_style(long_item), "left: calc(30.000%"
    assert_includes calendar_day_item_style(long_item), "width: calc(70.000%"
  end
end

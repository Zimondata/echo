module CalendarEventsHelper
  RUSSIAN_MONTHS = %w[
    января февраля марта апреля мая июня июля августа сентября октября ноября декабря
  ].freeze

  RUSSIAN_MONTHS_NOMINATIVE = %w[
    Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь
  ].freeze

  RUSSIAN_WEEKDAYS = %w[Понедельник Вторник Среда Четверг Пятница Суббота Воскресенье].freeze
  SHORT_WEEKDAYS = %w[Пн Вт Ср Чт Пт Сб Вс].freeze

  def calendar_period_title(view, date)
    case view
    when "day"
      "#{date.day} #{RUSSIAN_MONTHS[date.month - 1]} #{date.year}"
    when "week"
      week_start = date.beginning_of_week(:monday)
      week_end = date.end_of_week(:monday)
      if week_start.month == week_end.month
        "#{week_start.day}–#{week_end.day} #{RUSSIAN_MONTHS[week_start.month - 1]} #{week_end.year}"
      else
        "#{week_start.day} #{RUSSIAN_MONTHS[week_start.month - 1]} – #{week_end.day} #{RUSSIAN_MONTHS[week_end.month - 1]}"
      end
    else
      "#{RUSSIAN_MONTHS_NOMINATIVE[date.month - 1]} #{date.year}"
    end
  end

  def calendar_day_heading(date)
    "#{RUSSIAN_WEEKDAYS[date.cwday - 1]}, #{date.day} #{RUSSIAN_MONTHS[date.month - 1]}"
  end

  def calendar_event_time(event, timezone)
    return "Весь день" if event.all_day?

    starts_at = event.start_time.in_time_zone(timezone).strftime("%H:%M")
    return starts_at unless event.end_time

    "#{starts_at}–#{event.end_time.in_time_zone(timezone).strftime('%H:%M')}"
  end

  def calendar_event_color(event)
    event.display_color.presence || "#8b5cf6"
  end

  def calendar_event_duration_label(event)
    return "Весь день" if event.all_day?

    minutes = event.duration_minutes
    return "1 ч" if minutes.blank?
    return "#{minutes} мин" if minutes < 60

    hours = minutes / 60
    remainder = minutes % 60
    remainder.zero? ? "#{hours} ч" : "#{hours} ч #{remainder} мин"
  end

  def calendar_event_draggable?(event)
    duration = event.duration_minutes || 60
    !event.all_day? && duration.between?(5, 720)
  end

  def calendar_day_interval(record, date, timezone)
    calendar_bounded_interval(record, date, timezone, start_hour: 6, end_hour: 24)
  end

  def calendar_day_early_interval(record, date, timezone)
    calendar_bounded_interval(record, date, timezone, start_hour: 0, end_hour: 6)
  end

  def calendar_bounded_interval(record, date, timezone, start_hour:, end_hour:)
    zone = ActiveSupport::TimeZone[timezone] || Time.zone
    day_start = if start_hour.zero?
      zone.local(date.year, date.month, date.day)
    else
      zone.local(date.year, date.month, date.day, start_hour)
    end
    day_end = if end_hour == 24
      next_date = date.next_day
      zone.local(next_date.year, next_date.month, next_date.day)
    else
      zone.local(date.year, date.month, date.day, end_hour)
    end
    source_start = record.is_a?(TimeBlock) ? record.starts_at.in_time_zone(zone) : record.start_time.in_time_zone(zone)
    source_end = if record.is_a?(TimeBlock)
      record.ends_at.in_time_zone(zone)
    else
      (record.end_time || record.start_time + 1.hour).in_time_zone(zone)
    end
    visible_start = [ source_start, day_start ].max
    visible_end = [ source_end, day_end ].min
    return if visible_end <= visible_start

    {
      source_start: source_start,
      source_end: source_end,
      start: visible_start,
      end: visible_end,
      day_start: day_start,
      day_end: day_end
    }
  end

  def calendar_day_timeline_layout(events, time_blocks, date, timezone)
    entries = (events.map { |record| [ "calendar-event", record ] } +
      time_blocks.map { |record| [ "time-block", record ] }).filter_map do |kind, record|
      interval = calendar_day_interval(record, date, timezone)
      next unless interval

      minimum_render_end = interval[:start] + (32.0 / 56.0).hours
      interval.merge(kind: kind, record: record, render_end: [ interval[:end], minimum_render_end ].max)
    end.sort_by { |entry| [ entry[:start], entry[:end] ] }

    clusters = []
    cluster = []
    cluster_end = nil
    entries.each do |entry|
      if cluster.any? && entry[:start] >= cluster_end
        clusters << cluster
        cluster = []
        cluster_end = nil
      end
      cluster << entry
      cluster_end = [ cluster_end, entry[:render_end] ].compact.max
    end
    clusters << cluster if cluster.any?

    clusters.flat_map do |items|
      lane_ends = []
      items.each do |item|
        lane = lane_ends.index { |lane_end| lane_end <= item[:start] } || lane_ends.length
        lane_ends[lane] = item[:render_end]
        item[:lane] = lane
      end
      items.each { |item| item[:lanes] = lane_ends.length }
      actual_overlap = items.combination(2).any? do |left_item, right_item|
        left_item[:start] < right_item[:end] && right_item[:start] < left_item[:end]
      end
      if lane_ends.length == 2 && !actual_overlap
        lane_durations = items.group_by { |item| item[:lane] }.transform_values do |lane_items|
          lane_items.sum { |item| [ item[:end] - item[:start], 5.minutes ].max }
        end
        duration_total = lane_durations.values.sum
        first_lane_ratio = (lane_durations.fetch(0) / duration_total).clamp(0.3, 0.7)
        lane_widths = { 0 => first_lane_ratio, 1 => 1.0 - first_lane_ratio }
        items.each do |item|
          item[:lane_width_ratio] = lane_widths.fetch(item[:lane])
          item[:lane_left_ratio] = item[:lane].zero? ? 0.0 : lane_widths.fetch(0)
        end
      end
      items
    end
  end

  def calendar_day_item_style(item)
    top = (((item[:start] - item[:day_start]) / 1.hour) * 56).round
    height = [ (((item[:end] - item[:start]) / 1.hour) * 56).round, 32 ].max
    lane_width = (item[:lane_width_ratio] || (1.0 / item[:lanes])) * 100
    lane_left = (item[:lane_left_ratio] || ((1.0 / item[:lanes]) * item[:lane])) * 100
    color = item[:kind] == "calendar-event" ? "--event-color: #{calendar_event_color(item[:record])}; " : ""
    "#{color}top: #{top}px; height: #{height}px; left: calc(#{format('%.3f', lane_left)}% + 4px); right: auto; width: calc(#{format('%.3f', lane_width)}% - 8px)"
  end

  def calendar_day_item_time(item)
    starts_at = item[:start].strftime("%H:%M")
    ends_at = if item[:end] == item[:day_end] && item[:day_end].to_date > item[:day_start].to_date
      "24:00"
    else
      item[:end].strftime("%H:%M")
    end
    prefix = item[:source_start] < item[:day_start] ? "↤ " : ""
    suffix = item[:source_end] > item[:day_end] ? " ↦" : ""
    "#{prefix}#{starts_at}–#{ends_at}#{suffix}"
  end

  def calendar_week_event_style(event, timezone)
    starts_at = event.start_time.in_time_zone(timezone)
    ends_at = (event.end_time || event.start_time + 1.hour).in_time_zone(timezone)
    day_start_minutes = 6 * 60
    day_end_minutes = 24 * 60
    start_minutes = [ [ starts_at.hour * 60 + starts_at.min, day_start_minutes ].max, day_end_minutes ].min
    end_minutes = [ [ ends_at.hour * 60 + ends_at.min, day_start_minutes ].max, day_end_minutes ].min
    top = ((start_minutes - day_start_minutes) / 60.0 * 56).round
    height = [ ((end_minutes - start_minutes) / 60.0 * 56).round, 32 ].max

    "--event-color: #{calendar_event_color(event)}; top: #{top}px; height: #{height}px"
  end

  def time_block_time(time_block, timezone)
    starts_at = time_block.starts_at.in_time_zone(timezone).strftime("%H:%M")
    ends_at = time_block.ends_at.in_time_zone(timezone).strftime("%H:%M")
    "#{starts_at}–#{ends_at}"
  end

  def calendar_week_time_block_style(time_block, timezone)
    starts_at = time_block.starts_at.in_time_zone(timezone)
    ends_at = time_block.ends_at.in_time_zone(timezone)
    day_start_minutes = 6 * 60
    day_end_minutes = 24 * 60
    start_minutes = [ [ starts_at.hour * 60 + starts_at.min, day_start_minutes ].max, day_end_minutes ].min
    end_minutes = [ [ ends_at.hour * 60 + ends_at.min, day_start_minutes ].max, day_end_minutes ].min
    top = ((start_minutes - day_start_minutes) / 60.0 * 56).round
    height = [ ((end_minutes - start_minutes) / 60.0 * 56).round, 32 ].max

    "top: #{top}px; height: #{height}px"
  end

  def calendar_current_time_top(timezone)
    now = Time.current.in_time_zone(timezone)
    minutes = [ [ now.hour * 60 + now.min, 6 * 60 ].max, 24 * 60 ].min
    (((minutes - 6 * 60) / 60.0) * 56).round
  end

  def calendar_view_path(view, date)
    calendar_events_path(view: view, date: date.iso8601)
  end
end

require "test_helper"

class CalendarEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    assert_response :success
  end

  test "unauthenticated index redirects" do
    reset!

    get calendar_events_url

    assert_redirected_to root_path
  end

  test "index hides another user's and soft-deleted events" do
    @user.calendar_events.create!(
      title: "Удалённое событие",
      start_time: Time.zone.parse("2026-07-29 10:00"),
      event_type: "plan",
      priority: "medium",
      deleted_at: Time.current
    )
    users(:moscow_user).calendar_events.create!(
      title: "Чужое событие",
      start_time: Time.zone.parse("2026-07-29 11:00"),
      event_type: "plan",
      priority: "medium"
    )

    get calendar_events_url(date: "2026-07-29", view: "month")

    assert_response :success
    assert_no_match "Удалённое событие", response.body
    assert_no_match "Чужое событие", response.body
  end

  test "timezone midnight event appears on the user's local date" do
    @user.calendar_events.create!(
      title: "После полуночи локально",
      start_time: Time.utc(2026, 7, 29, 21, 30),
      end_time: Time.utc(2026, 7, 29, 22, 30),
      event_type: "meeting",
      priority: "medium"
    )

    get calendar_events_url(date: "2026-07-30", view: "month")

    assert_response :success
    assert_select "[data-calendar-date='2026-07-30'] .calendar-event-title", text: "После полуночи локально"
  end

  test "all-day and script-like event content render safely" do
    @user.calendar_events.create!(
      title: "<script>alert('x')</script>",
      description: "<img src=x onerror=alert(1)>",
      start_time: Time.zone.parse("2026-07-29 00:00"),
      event_type: "plan",
      priority: "medium",
      all_day: true
    )

    get calendar_events_url(date: "2026-07-29", view: "month")

    assert_response :success
    assert_select "[data-calendar-date='2026-07-29'] .calendar-event-time", text: "весь день"
    assert_select "script", text: /alert\('x'\)/, count: 0
    assert_includes response.body, "&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;"
  end

  test "month view is a real navigable calendar" do
    travel_to Time.zone.parse("2026-07-29 10:00") do
      event = @user.calendar_events.create!(
        title: "Созвон по Echo",
        start_time: Time.zone.parse("2026-07-29 14:00"),
        end_time: Time.zone.parse("2026-07-29 15:00"),
        event_type: "meeting",
        priority: "high",
        life_category: "work"
      )

      get calendar_events_url(date: "2026-07-29", view: "month")

      assert_response :success
      assert_select "[data-calendar-view='month']"
      assert_select "a[href*='view=day'][href*='date=2026-07-29']"
      assert_select "a[href='#{edit_calendar_event_path(event)}']", text: /Созвон по Echo/
      assert_select "a", text: "Сегодня"
      assert_select "button.calendar-primary-link[data-action*='calendar-quick-create#open']", text: /Создать/
      assert_select "[data-controller~='planner-drag'][data-planner-drag-view-value='month']"
      assert_select "[data-calendar-date='2026-07-29'][data-planner-drag-target='day'][data-action*='planner-drag#monthDrop'][data-action*='calendar-quick-create#openMonth']"
      assert_select "[data-planner-drag-kind='calendar-event'][data-planner-drag-event-id='#{event.id}'][data-planner-drag-local-time='#{event.start_time.in_time_zone(@user.timezone).strftime('%H:%M')}'][draggable='true']"
      assert_select "dialog[data-calendar-quick-create-target='dialog']" do
        assert_select "form[action='#{calendar_events_path}'] input[name='calendar_event[title]']"
        assert_select "input[name='calendar_event[start_time]']"
        assert_select "input[name='calendar_event[end_time]']"
        assert_select "[data-duration-minutes]", minimum: 4
        assert_select "form[action='#{entries_path}'] textarea[name='entry[content]']"
      end
    end
  end

  test "week view renders seven days and timed events" do
    travel_to Time.zone.parse("2026-07-29 10:00") do
      @user.calendar_events.create!(
        title: "Глубокая работа",
        start_time: Time.zone.parse("2026-07-30 09:30"),
        end_time: Time.zone.parse("2026-07-30 11:00"),
        event_type: "plan",
        priority: "medium",
        life_category: "projects"
      )

      get calendar_events_url(date: "2026-07-29", view: "week")

      assert_response :success
      assert_select "[data-calendar-view='week']"
      assert_select "[data-controller~='planner-drag'][data-planner-drag-view-value='week']"
      assert_select "[data-calendar-day][data-action*='calendar-quick-create#openWeek']", count: 7
      expected_top = (((Time.current.in_time_zone(@user.timezone).hour * 60 + Time.current.in_time_zone(@user.timezone).min - 6 * 60) / 60.0) * 56).round
      assert_select "[data-current-time-line][style*='top: #{expected_top}px']", count: 1
      assert_select "[data-calendar-day]", count: 7
      assert_select "[data-event-title]", text: /Глубокая работа/
    end
  end

  test "day view renders the selected date as an hourly timeline even when empty" do
    get calendar_events_url(date: "2026-08-12", view: "day")

    assert_response :success
    assert_select "[data-calendar-view='day']"
    assert_select "[data-day-timeline][data-calendar-day='2026-08-12']", count: 1
    assert_select ".calendar-day-time-label", count: 18
    assert_select "[data-day-free-state]", text: /свободен/i
    assert_select "button[data-quick-create-date='2026-08-12']"
  end

  test "day view clips an event that started on a previous day" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(
      title: "Выезд с ночёвкой",
      start_time: zone.local(2026, 8, 11, 18),
      end_time: zone.local(2026, 8, 12, 10),
      event_type: "meeting",
      priority: "medium",
      life_category: "personal"
    )

    get calendar_events_url(date: "2026-08-12", view: "day")

    assert_response :success
    assert_select "[data-day-timeline] [data-day-layout-item='calendar-event'][style*='top: 0px'][style*='height: 224px']" do
      assert_select ".calendar-week-event-time", text: "↤ 06:00–10:00"
      assert_select ".calendar-week-event-title", text: "Выезд с ночёвкой"
    end
  end

  test "day view clips a multi-day event on its first and final visible dates" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(
      title: "Длинный выезд",
      start_time: zone.local(2026, 8, 11, 18),
      end_time: zone.local(2026, 8, 13, 10),
      event_type: "meeting",
      priority: "medium",
      life_category: "personal"
    )

    get calendar_events_url(date: "2026-08-11", view: "day")
    assert_select "[data-day-layout-item='calendar-event'][style*='top: 672px'][style*='height: 336px']" do
      assert_select ".calendar-week-event-time", text: "18:00–24:00 ↦"
    end

    get calendar_events_url(date: "2026-08-13", view: "day")
    assert_select "[data-day-layout-item='calendar-event'][style*='top: 0px'][style*='height: 224px']" do
      assert_select ".calendar-week-event-time", text: "↤ 06:00–10:00"
    end
  end

  test "events wholly before the visible timeline stay accessible outside the grid" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(
      title: "Ранний трансфер",
      start_time: zone.local(2026, 8, 12, 1),
      end_time: zone.local(2026, 8, 12, 5),
      event_type: "meeting",
      priority: "medium"
    )

    get calendar_events_url(date: "2026-08-12", view: "day")

    assert_select "[data-day-outside-grid]", text: /Ранний трансфер/
    assert_select "[data-day-timeline] .calendar-week-event-title", text: "Ранний трансфер", count: 0
  end

  test "overnight events and tasks ending before six are clipped to the selected date" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(
      title: "Ночной переезд",
      start_time: zone.local(2026, 8, 11, 23),
      end_time: zone.local(2026, 8, 12, 5),
      event_type: "meeting",
      priority: "medium"
    )
    task = @user.tasks.create!(title: "Ночная задача", status: "scheduled")
    task.time_blocks.create!(
      starts_at: zone.local(2026, 8, 11, 23, 30),
      ends_at: zone.local(2026, 8, 12, 4, 30),
      source: "manual",
      previous_task_status: "next"
    )

    get calendar_events_url(date: "2026-08-12", view: "day")

    assert_select "[data-day-outside-grid] a", text: /↤ 00:00–05:00 · Ночной переезд/
    assert_select "[data-day-outside-grid] a", text: /↤ 00:00–04:30 · Ночная задача/
  end

  test "an event ending at midnight is not duplicated onto the next day" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(
      title: "До полуночи",
      start_time: zone.local(2026, 8, 11, 20),
      end_time: zone.local(2026, 8, 12, 0),
      event_type: "meeting",
      priority: "medium"
    )

    get calendar_events_url(date: "2026-08-12", view: "day")

    assert_select ".calendar-week-event-title", text: "До полуночи", count: 0
  end

  test "overlapping events and tasks receive separate visible lanes" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "Параллель A", start_time: zone.local(2026, 8, 12, 10), end_time: zone.local(2026, 8, 12, 12), event_type: "meeting", priority: "medium")
    @user.calendar_events.create!(title: "Параллель B", start_time: zone.local(2026, 8, 12, 10, 30), end_time: zone.local(2026, 8, 12, 11, 30), event_type: "meeting", priority: "medium")
    task = @user.tasks.create!(title: "Параллельная задача", status: "scheduled")
    task.time_blocks.create!(starts_at: zone.local(2026, 8, 12, 10, 45), ends_at: zone.local(2026, 8, 12, 11, 15), source: "manual", previous_task_status: "next")

    get calendar_events_url(date: "2026-08-12", view: "day")

    styles = css_select("[data-day-layout-item]").filter_map { |node| node["style"] if node.text.match?(/Параллель/) }
    assert_equal 3, styles.size
    assert_equal 3, styles.uniq.size
    assert styles.all? { |style| style.include?("width: calc(33.333") }
  end

  test "minimum-height adjacent items receive separate visible lanes" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "Короткое событие", start_time: zone.local(2026, 8, 12, 10), end_time: zone.local(2026, 8, 12, 10, 5), event_type: "meeting", priority: "medium")
    task = @user.tasks.create!(title: "Короткая задача", status: "scheduled")
    task.time_blocks.create!(starts_at: zone.local(2026, 8, 12, 10, 10), ends_at: zone.local(2026, 8, 12, 10, 15), source: "manual", previous_task_status: "next")

    get calendar_events_url(date: "2026-08-12", view: "day")

    styles = css_select("[data-day-layout-item]").filter_map { |node| node["style"] if node.text.match?(/Коротк/) }
    assert_equal 2, styles.size
    assert_equal 2, styles.uniq.size
    assert styles.all? { |style| style.include?("width: calc(50.000") }
  end

  test "invalid date and view fall back without crashing" do
    get calendar_events_url(date: "not-a-date", view: "timeline")

    assert_response :success
    assert_select "[data-calendar-view='month']"
  end

  test "creates a user-owned event from the manual form" do
    assert_difference "@user.calendar_events.count", 1 do
      post calendar_events_url, params: {
        calendar_event: {
          user_id: users(:moscow_user).id,
          title: "Тренировка",
          description: "Спокойный темп",
          start_time: "2026-08-03T07:00",
          end_time: "2026-08-03T08:00",
          event_type: "plan",
          priority: "medium",
          life_category: "health",
          reminder_minutes: 30
        }
      }
    end

    event = @user.calendar_events.order(:created_at).last
    assert_equal @user.id, event.user_id
    assert_equal "Тренировка", event.title
    assert_equal "07:00", event.start_time.in_time_zone(@user.timezone).strftime("%H:%M")
    assert_redirected_to calendar_events_path(date: "2026-08-03", view: "day")
  end

  test "quick create returns to the same calendar period" do
    assert_difference "@user.calendar_events.count", 1 do
      post calendar_events_url, params: {
        return_view: "month",
        return_date: "2026-08-03",
        calendar_event: {
          title: "Быстрый план",
          start_time: "2026-08-03T10:15",
          end_time: "2026-08-03T11:00",
          event_type: "plan",
          priority: "medium",
          life_category: "work"
        }
      }
    end

    assert_redirected_to calendar_events_path(date: "2026-08-03", view: "month")
  end

  test "cannot read or update another user's event" do
    event = calendar_events(:two)
    original_title = event.title

    get edit_calendar_event_url(event)
    assert_redirected_to calendar_events_path

    patch calendar_event_url(event), params: { calendar_event: { title: "Чужое изменение" } }
    assert_redirected_to calendar_events_path
    assert_equal original_title, event.reload.title
  end

  test "invalid event re-renders the form" do
    assert_no_difference "CalendarEvent.count" do
      post calendar_events_url, params: {
        calendar_event: {
          title: "",
          start_time: "2026-08-03T07:00",
          event_type: "plan",
          priority: "medium"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[data-form-errors]"
  end

  test "updates an owned event" do
    event = calendar_events(:one)

    patch calendar_event_url(event), params: {
      calendar_event: { title: "Обновлённая встреча", priority: "urgent" }
    }

    assert_redirected_to calendar_events_path(date: event.start_time.in_time_zone(@user.timezone).to_date.iso8601, view: "day")
    assert_equal "Обновлённая встреча", event.reload.title
    assert_equal "urgent", event.priority
  end

  test "moves an owned timed event through the week drag contract while preserving duration" do
    zone = Time.find_zone!(@user.timezone)
    event = @user.calendar_events.create!(
      title: "Передвинь встречу",
      start_time: zone.local(2026, 8, 3, 10),
      end_time: zone.local(2026, 8, 3, 11, 30),
      event_type: "meeting",
      priority: "medium"
    )

    patch calendar_event_url(event), params: {
      calendar_event: {
        local_date: "2026-08-05",
        local_time: "14:15",
        duration_minutes: "90",
        timezone: @user.timezone,
        lock_version: event.lock_version
      },
      view: "week",
      date: "2026-08-05"
    }

    assert_redirected_to calendar_events_path(date: "2026-08-05", view: "week")
    assert_equal "2026-08-05 14:15", event.reload.start_time.in_time_zone(@user.timezone).strftime("%F %H:%M")
    assert_equal 90.minutes, event.end_time - event.start_time
  end

  test "month drag returns to month while preserving local time" do
    zone = Time.find_zone!(@user.timezone)
    event = @user.calendar_events.create!(
      title: "Перенос по месяцу",
      start_time: zone.local(2026, 8, 3, 14),
      end_time: zone.local(2026, 8, 3, 15),
      event_type: "plan",
      priority: "medium"
    )

    patch calendar_event_url(event), params: {
      calendar_event: {
        local_date: "2026-08-07",
        local_time: "14:00",
        duration_minutes: "60",
        timezone: @user.timezone,
        lock_version: event.lock_version
      },
      view: "month",
      date: "2026-08-07"
    }

    assert_redirected_to calendar_events_path(date: "2026-08-07", view: "month")
    assert_equal "2026-08-07 14:00", event.reload.start_time.in_time_zone(@user.timezone).strftime("%F %H:%M")
  end

  test "event drag rejects a stale page timezone without changing the event" do
    event = calendar_events(:one)
    before = event.attributes.slice("start_time", "end_time")
    stale_timezone = @user.timezone
    @user.update!(timezone: "Europe/London")

    patch calendar_event_url(event), params: {
      calendar_event: {
        local_date: "2026-08-05",
        local_time: "14:15",
        duration_minutes: "60",
        timezone: stale_timezone,
        lock_version: event.lock_version
      },
      view: "week",
      date: "2026-08-05"
    }

    assert_redirected_to calendar_events_path(date: "2026-08-05", view: "week")
    assert_equal "Страница устарела. Обнови календарь и повтори перенос.", flash[:alert]
    assert_equal before, event.reload.attributes.slice("start_time", "end_time")
  end

  test "event drag rejects stale lock version without overwriting a newer move" do
    event = calendar_events(:one)
    stale_version = event.lock_version
    event.update!(start_time: event.start_time + 2.hours, end_time: event.end_time + 2.hours)
    server_times = event.attributes.slice("start_time", "end_time")

    patch calendar_event_url(event), params: {
      calendar_event: {
        local_date: "2026-08-05",
        local_time: "14:15",
        duration_minutes: "60",
        timezone: @user.timezone,
        lock_version: stale_version
      }
    }

    assert_redirected_to calendar_events_path(date: "2026-08-05", view: "week")
    assert_equal "Событие изменилось или перенос устарел. Обнови календарь и повтори.", flash[:alert]
    assert_equal server_times, event.reload.attributes.slice("start_time", "end_time")
  end

  test "event drag rejects overlap with another owned event" do
    zone = Time.find_zone!(@user.timezone)
    event = calendar_events(:one)
    @user.calendar_events.create!(
      title: "Уже занято",
      start_time: zone.local(2026, 8, 5, 14),
      end_time: zone.local(2026, 8, 5, 15),
      event_type: "meeting",
      priority: "medium"
    )
    before = event.attributes.slice("start_time", "end_time")

    patch calendar_event_url(event), params: {
      calendar_event: {
        local_date: "2026-08-05",
        local_time: "14:15",
        duration_minutes: "60",
        timezone: @user.timezone,
        lock_version: event.lock_version
      }
    }

    assert_redirected_to calendar_events_path(date: "2026-08-05", view: "week")
    assert_equal "Новое время пересекается с другим блоком или событием.", flash[:alert]
    assert_equal before, event.reload.attributes.slice("start_time", "end_time")
  end

  test "removes an owned event without deleting the record" do
    event = calendar_events(:one)

    assert_no_difference "CalendarEvent.count" do
      delete calendar_event_url(event)
    end

    assert event.reload.deleted_at.present?
    assert_redirected_to calendar_events_path
  end

  test "index renders the unscheduled task lane with a quick add form" do
    get calendar_events_url

    assert_response :success
    assert_select "turbo-frame#task_lane"
    assert_select "[data-task-form]", count: 1
    assert_select "[data-task-form] input[name='task[title]']"
    assert_select "[data-task-card]", text: /Собрать материалы для отчёта/
    assert_select "[data-task-card]", text: /Подготовить вопросы к созвону/
    assert_no_match "Придумать название для подкаста", response.body
  end

  test "task cards expose edit complete and drop controls without duplicate DOM ids" do
    get calendar_events_url

    assert_response :success
    [ tasks(:inbox_task), tasks(:next_task) ].each do |task|
      assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(task)}"
      assert_select "form[action='#{task_path(task)}']"
      assert_select "form[action='#{complete_task_path(task)}']"
      assert_select "form[action='#{drop_task_path(task)}']"
    end

    ids = css_select("#task_lane [id]").map { |node| node["id"] }
    assert_equal ids.uniq, ids
  end

  test "task lane escapes script-like task content" do
    @user.tasks.create!(title: "<script>alert('task')</script>")

    get calendar_events_url

    assert_response :success
    assert_select "script", text: /alert\('task'\)/, count: 0
    assert_includes response.body, "&lt;script&gt;alert(&#39;task&#39;)&lt;/script&gt;"
  end

  test "task lane hides another user's, soft-deleted and already scheduled tasks" do
    get calendar_events_url

    assert_response :success
    assert_no_match "Чужая задача", response.body
    assert_no_match "Удалённая задача", response.body
    assert_no_match "Уже стоит в календаре", response.body
  end

  test "week view exposes a bounded drag contract for unscheduled tasks flexible blocks and timed events" do
    zone = Time.find_zone!(@user.timezone)
    event = @user.calendar_events.create!(
      title: "Перетащи встречу",
      start_time: zone.local(2026, 8, 3, 12),
      end_time: zone.local(2026, 8, 3, 13),
      event_type: "meeting",
      priority: "medium"
    )
    task = @user.tasks.create!(title: "Перетащи меня", status: "next", estimate_minutes: 45)
    scheduled_task = @user.tasks.create!(title: "Подвинь меня", status: "scheduled")
    block = scheduled_task.time_blocks.create!(
      starts_at: Time.find_zone!(@user.timezone).local(2026, 8, 3, 10),
      ends_at: Time.find_zone!(@user.timezone).local(2026, 8, 3, 11),
      previous_task_status: "next"
    )
    locked_task = @user.tasks.create!(title: "Зафиксирован", status: "scheduled")
    locked_block = locked_task.time_blocks.create!(
      starts_at: Time.find_zone!(@user.timezone).local(2026, 8, 4, 10),
      ends_at: Time.find_zone!(@user.timezone).local(2026, 8, 4, 11),
      locked: true,
      previous_task_status: "inbox"
    )

    get calendar_events_url(date: "2026-08-03", view: "week")

    assert_response :success
    assert_select "[data-controller~='planner-drag'][data-planner-drag-timezone-value='#{@user.timezone}']"
    assert_select "[data-planner-drag-kind='task'][data-planner-drag-task-id='#{task.id}'][data-planner-drag-duration='45'][draggable='true']"
    assert_select "[data-planner-drag-kind='time-block'][data-planner-drag-time-block-id='#{block.id}'][data-planner-drag-duration='60'][draggable='true']"
    assert_select "[data-planner-drag-kind='time-block'][data-planner-drag-time-block-id='#{locked_block.id}'][draggable='false']"
    assert_select "[data-planner-drag-kind='calendar-event'][data-planner-drag-event-id='#{event.id}'][data-planner-drag-duration='60'][draggable='true'][data-planner-touch-enabled='true'][data-action*='pointerdown->planner-drag#pointerStart'][data-action*='pointermove->planner-drag#pointerMove'][data-action*='pointerup->planner-drag#pointerEnd']"
    assert_select "[data-planner-drag-target='day'][data-action*='drop->planner-drag#drop']", count: 7
    assert_select ".calendar-week .calendar-week-day[data-planner-drag-target='day'][data-calendar-date]", count: 7
    assert_select ".calendar-week .calendar-week-event[data-planner-drag-event-id='#{event.id}'][data-planner-drag-event-lock-version='#{event.lock_version}'][data-planner-drag-local-time='#{event.start_time.in_time_zone(@user.timezone).strftime("%H:%M")}'][data-planner-touch-enabled='true'][data-action*='pointerdown->planner-drag#pointerStart']", count: 1
    assert_select "[data-planner-drag-hint]", text: /Перетащи задачу/
  end

  test "day view exposes precision drag while month keeps the form path" do
    task = @user.tasks.create!(title: "Поставить во время", status: "inbox")

    get calendar_events_url(date: "2026-08-03", view: "day")

    assert_response :success
    assert_select "[data-controller~='planner-drag'][data-planner-drag-view-value='day']", count: 1
    assert_select "[data-day-timeline][data-planner-drag-target='day'][data-action*='drop->planner-drag#drop']", count: 1
    assert_select "[data-planner-drag-task-id='#{task.id}'][draggable='true']"
    assert_select "[data-planner-drag-hint]", text: /Перетащи задачу/

    get calendar_events_url(date: "2026-08-03", view: "month")

    assert_response :success
    assert_select "[data-planner-drag-task-id='#{task.id}'][draggable='false']"
    assert_select "summary", text: "Запланировать"
  end

  test "successful event drag remains in day view" do
    zone = Time.find_zone!(@user.timezone)
    event = @user.calendar_events.create!(title: "Перенос внутри дня", start_time: zone.local(2026, 8, 20, 9), end_time: zone.local(2026, 8, 20, 10), event_type: "plan", priority: "medium")

    patch calendar_event_url(event), params: {
      calendar_event: {
        local_date: "2026-08-20",
        local_time: "11:00",
        duration_minutes: "60",
        timezone: @user.timezone,
        lock_version: event.lock_version
      },
      view: "day",
      date: "2026-08-20"
    }

    assert_redirected_to calendar_events_path(date: "2026-08-20", view: "day")
  end

  test "all-day and longer-than-twelve-hour events are not advertised as draggable" do
    zone = Time.find_zone!(@user.timezone)
    all_day = @user.calendar_events.create!(title: "Весь день", start_time: zone.local(2026, 8, 20), end_time: zone.local(2026, 8, 20, 23, 59), all_day: true, event_type: "plan", priority: "medium")
    long = @user.calendar_events.create!(title: "Длинный переезд", start_time: zone.local(2026, 8, 21, 6), end_time: zone.local(2026, 8, 21, 20), event_type: "meeting", priority: "medium")

    get calendar_events_url(date: "2026-08-01", view: "month")

    assert_select "a[href='#{edit_calendar_event_path(all_day)}'][draggable='false']", count: 1
    assert_select "a[href='#{edit_calendar_event_path(long)}'][draggable='false']", count: 1
  end

  test "Plan keeps the calendar primary and task lane collapsed without side rails" do
    get calendar_events_url(date: "2026-08-03", view: "month")

    assert_response :success
    assert_select ".calendar-workspace > .calendar-surface", count: 1
    assert_select ".task-lane[open]", count: 0
    assert_select ".calendar-sidebar", count: 0
    assert_select "[data-rhythm-plan]", count: 0
  end

  test "task lane shows an honest empty state when nothing waits for time" do
    @user.tasks.destroy_all

    get calendar_events_url

    assert_response :success
    assert_select ".task-lane-heading", text: "Задачи без времени"
    assert_select "[data-task-lane-empty]", text: "Добавь задачу здесь. Она останется в этом списке, пока ты не назначишь ей дату и время."
    assert_select "[data-task-card]", count: 0
  end
end

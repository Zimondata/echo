require "test_helper"

class TimeBlocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    assert_response :success
    @task = tasks(:inbox_task)
  end

  test "schedules an unscheduled task as a separate time block atomically" do
    event_count = CalendarEvent.count

    assert_difference "TimeBlock.count", 1 do
      post task_time_blocks_url(@task), params: schedule_params(date: "2026-08-03", time: "14:30", duration: "45")
    end

    block = @task.time_blocks.last
    assert_equal "scheduled", @task.reload.status
    assert_equal "inbox", block.previous_task_status
    assert_equal "manual", block.source
    assert_equal "14:30", block.starts_at.in_time_zone(@user.timezone).strftime("%H:%M")
    assert_equal 45.minutes, block.ends_at - block.starts_at
    assert_equal event_count, CalendarEvent.count
    assert_redirected_to calendar_events_path(view: "day", date: "2026-08-03")
  end

  test "invalid duration rolls back the task transition and preserves the schedule form" do
    assert_no_difference "TimeBlock.count" do
      post task_time_blocks_url(@task), params: schedule_params(duration: "0")
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(@task)}"
    assert_select "[data-schedule-errors]"
    assert_select "details.task-card-scheduler[open]"
    assert_select "input[name='time_block[duration_minutes]'][value='0']"
    assert_equal "inbox", @task.reload.status
  end

  test "missing malformed oversized and stale task locks write nothing" do
    stale = @task.lock_version
    @task.update!(title: "Свежая версия")

    [ nil, "abc", "9" * 30, stale ].each do |lock|
      assert_no_difference "TimeBlock.count" do
        payload = schedule_params(lock_version: lock)
        payload[:task].delete(:lock_version) if lock.nil?
        post task_time_blocks_url(@task), params: payload
      end

      assert_response :conflict
      assert_select "[data-schedule-conflict]"
      assert_equal "inbox", @task.reload.status
    end
  end

  test "foreign deleted and non-unscheduled tasks cannot be scheduled" do
    targets = [ tasks(:other_user_task), tasks(:deleted_task), tasks(:scheduled_task), tasks(:someday_task) ]

    targets.each do |task|
      assert_no_difference "TimeBlock.count" do
        post task_time_blocks_url(task), params: schedule_params(lock_version: task.lock_version)
      end
      assert_response :not_found
    end
  end

  test "DST gap and fold are rejected instead of silently normalized" do
    @user.update!(timezone: "Europe/Madrid")
    [
      [ "2026-03-29", "02:30" ],
      [ "2026-10-25", "02:30" ]
    ].each do |date, time|
      task = @user.tasks.create!(title: "DST #{date}", owner_type: "user", status: "inbox")
      assert_no_difference "TimeBlock.count" do
        post task_time_blocks_url(task), params: schedule_params(date: date, time: time, lock_version: task.lock_version)
      end
      assert_response :unprocessable_entity
      assert_match(/время/i, response.body)
      assert_equal "inbox", task.reload.status
    end
  end

  test "create rejects a stale page timezone without scheduling or shifting the task" do
    stale_timezone = @user.timezone
    @user.update!(timezone: "Europe/London")

    assert_no_difference "TimeBlock.count" do
      post task_time_blocks_url(@task), params: schedule_params(timezone: stale_timezone)
    end

    assert_response :conflict
    assert_select "[data-schedule-conflict]"
    assert_select "input[name='time_block[timezone]'][value='#{stale_timezone}']"
    assert_equal "inbox", @task.reload.status
  end

  test "overlap requires explicit confirmation while adjacent blocks do not" do
    @user.calendar_events.create!(
      title: "Fixed event",
      start_time: Time.find_zone!(@user.timezone).local(2026, 8, 3, 14, 0),
      end_time: Time.find_zone!(@user.timezone).local(2026, 8, 3, 15, 0),
      event_type: "meeting",
      priority: "medium"
    )

    assert_no_difference "TimeBlock.count" do
      post task_time_blocks_url(@task), params: schedule_params(date: "2026-08-03", time: "14:30", duration: "30")
    end
    assert_response :unprocessable_entity
    assert_select "[data-overlap-warning]"
    assert_select "[data-planner-drag-kind='task'][draggable='true']", count: 0
    assert_select "input[name='time_block[overlap_signature]']"
    signature = Nokogiri::HTML(response.body).at_css("input[name='time_block[overlap_signature]']")["value"]

    assert_difference "TimeBlock.count", 1 do
      post task_time_blocks_url(@task), params: schedule_params(date: "2026-08-03", time: "14:30", duration: "30", overlap_signature: signature)
    end

    adjacent = @user.tasks.create!(title: "Adjacent", owner_type: "user", status: "next")
    assert_difference "TimeBlock.count", 1 do
      post task_time_blocks_url(adjacent), params: schedule_params(date: "2026-08-03", time: "15:00", duration: "30", lock_version: adjacent.lock_version)
    end
  end

  test "retry after successful schedule creates exactly one active block" do
    lock = @task.lock_version
    post task_time_blocks_url(@task), params: schedule_params(lock_version: lock)
    assert_response :redirect

    assert_no_difference "TimeBlock.count" do
      post task_time_blocks_url(@task), params: schedule_params(lock_version: lock)
    end
    assert_response :conflict
    assert_equal 1, @task.time_blocks.active.count
  end

  test "overlap approval cannot be reused for a changed interval" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "Busy", start_time: zone.local(2026, 8, 3, 14), end_time: zone.local(2026, 8, 3, 16), event_type: "meeting", priority: "medium")

    post task_time_blocks_url(@task), params: schedule_params(time: "14:30")
    signature = Nokogiri::HTML(response.body).at_css("input[name='time_block[overlap_signature]']")["value"]

    assert_no_difference "TimeBlock.count" do
      post task_time_blocks_url(@task), params: schedule_params(time: "15:00", overlap_signature: signature)
    end
    assert_response :unprocessable_entity
    assert_select "[data-overlap-warning]"
  end

  test "an event without an end reserves the displayed default hour" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "Open ended", start_time: zone.local(2026, 8, 3, 10), end_time: nil, event_type: "meeting", priority: "medium")

    assert_no_difference "TimeBlock.count" do
      post task_time_blocks_url(@task), params: schedule_params(time: "10:30")
    end
    assert_response :unprocessable_entity
    assert_select "[data-overlap-warning]"
  end

  test "an all-day event reserves its displayed day" do
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "All day", start_time: zone.local(2026, 8, 3, 0), end_time: nil, all_day: true, event_type: "task", priority: "medium")

    assert_no_difference "TimeBlock.count" do
      post task_time_blocks_url(@task), params: schedule_params(time: "18:00")
    end
    assert_response :unprocessable_entity
    assert_select "[data-overlap-warning]"
  end

  test "a midnight-ending block is projected only on days it occupies" do
    zone = Time.find_zone!(@user.timezone)
    @task.update!(status: "scheduled")
    block = @task.time_blocks.create!(starts_at: zone.local(2026, 8, 3, 23), ends_at: zone.local(2026, 8, 4, 0), source: "manual", previous_task_status: "inbox")

    get calendar_events_url(view: "month", date: "2026-08-04")
    assert_response :success
    assert_select "[data-calendar-date='2026-08-03'] [data-time-block-id='#{block.id}']", count: 1
    assert_select "[data-calendar-date='2026-08-04'] [data-time-block-id='#{block.id}']", count: 0

    get calendar_events_url(view: "week", date: "2026-08-04")
    assert_response :success
    assert_select "[data-calendar-day='2026-08-03'] [data-time-block-id='#{block.id}']", count: 1
    assert_select "[data-calendar-mobile-day='2026-08-03'] [data-time-block-id='#{block.id}']", count: 1
    assert_select "[data-calendar-day='2026-08-04'] [data-time-block-id='#{block.id}']", count: 0
    assert_select "[data-calendar-mobile-day='2026-08-04'] [data-time-block-id='#{block.id}']", count: 0

    get calendar_events_url(view: "day", date: "2026-08-04")
    assert_select "[data-time-block-id='#{block.id}']", count: 0
  end

  test "unschedule cancels the block and restores the exact previous task status" do
    @task.update!(status: "next")
    post task_time_blocks_url(@task), params: schedule_params(lock_version: @task.lock_version)
    block = @task.time_blocks.active.first

    delete task_time_block_url(@task, block), params: {
      task: { lock_version: @task.reload.lock_version },
      time_block: { lock_version: block.lock_version },
      view: "day",
      date: "2026-08-03"
    }

    assert_redirected_to calendar_events_path(view: "day", date: "2026-08-03")
    assert_equal "next", @task.reload.status
    assert_predicate block.reload.cancelled_at, :present?
    assert_empty @task.time_blocks.active
  end

  test "calendar renders a distinct time block after refresh and task leaves the lane" do
    post task_time_blocks_url(@task), params: schedule_params(date: "2026-08-03", time: "14:30", duration: "45")
    block = @task.time_blocks.active.first

    [ "month", "week", "day" ].each do |view|
      get calendar_events_url(view: view, date: "2026-08-03")
      assert_response :success
      assert_select "[data-time-block-id='#{block.id}']", text: /#{Regexp.escape(@task.title)}/
      assert_select "#task_lane [data-task-card]", text: /#{Regexp.escape(@task.title)}/, count: 0
    end

    get calendar_events_url(view: "day", date: "2026-08-03")
    assert_select "form[action='#{task_time_block_path(@task, block)}']"
  end

  test "day view gives every unschedule lock input a unique DOM id" do
    zone = Time.find_zone!(@user.timezone)
    second_task = @user.tasks.create!(title: "Second scheduled", owner_type: "user", status: "scheduled")
    @task.update!(status: "scheduled")
    @task.time_blocks.create!(starts_at: zone.local(2026, 8, 3, 10), ends_at: zone.local(2026, 8, 3, 10, 30), previous_task_status: "inbox")
    second_task.time_blocks.create!(starts_at: zone.local(2026, 8, 3, 11), ends_at: zone.local(2026, 8, 3, 11, 30), previous_task_status: "next")

    get calendar_events_url(view: "day", date: "2026-08-03")
    ids = Nokogiri::HTML(response.body).css("[id]").map { |node| node["id"] }
    assert_equal ids.uniq, ids
  end

  test "edit form is reachable and reschedules the existing block in place" do
    block = existing_block
    task_before = @task.reload.attributes.slice("status", "title", "lock_version")
    immutable_block = block.attributes.slice("id", "task_id", "source", "previous_task_status", "cancelled_at")

    get edit_task_time_block_url(@task, block)
    assert_response :success
    assert_select "form[action='#{task_time_block_path(@task, block)}']"
    assert_select "input[name='time_block[local_date]'][value='2026-08-03']"
    assert_select "input[name='time_block[timezone]'][value='#{@user.timezone}']"

    assert_no_difference "TimeBlock.count" do
      patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-04", time: "15:15", duration: "75", locked: "1")
    end

    assert_redirected_to calendar_events_path(view: "day", date: "2026-08-04")
    assert_equal task_before, @task.reload.attributes.slice("status", "title", "lock_version")
    assert_equal immutable_block, block.reload.attributes.slice("id", "task_id", "source", "previous_task_status", "cancelled_at")
    assert_equal "15:15", block.starts_at.in_time_zone(@user.timezone).strftime("%H:%M")
    assert_equal 75, block.duration_minutes
    assert_predicate block, :locked?
  end

  test "every calendar projection exposes a keyboard-focusable edit link" do
    block = existing_block
    expected_href = edit_task_time_block_path(@task, block)

    %w[month week day].each do |view|
      get calendar_events_url(view: view, date: "2026-08-03")
      assert_response :success
      assert_select "a[href='#{expected_href}'][aria-label*='#{@task.title}']"
    end
  end

  test "month projects an unlocked time block as draggable and returns to month after drop" do
    block = existing_block

    get calendar_events_url(view: "month", date: "2026-08-03")
    assert_response :success
    assert_select "[data-planner-drag-kind='time-block'][data-planner-drag-time-block-id='#{block.id}'][data-planner-drag-local-time='10:00'][draggable='true']"

    params = reschedule_params(block, date: "2026-08-06", time: "10:00", duration: "30")
    params[:view] = "month"
    patch task_time_block_url(@task, block), params: params

    assert_redirected_to calendar_events_path(view: "month", date: "2026-08-06")
    assert_equal Date.new(2026, 8, 6), block.reload.starts_at.in_time_zone(@user.timezone).to_date
  end

  test "invalid reschedule preserves the exact draft and changes nothing" do
    block = existing_block
    before = block.attributes

    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-05", time: "17:45", duration: "4", locked: "1")

    assert_response :unprocessable_entity
    assert_equal before, block.reload.attributes
    assert_select "[data-reschedule-errors]"
    assert_select "input[name='time_block[local_date]'][value='2026-08-05']"
    assert_select "input[name='time_block[local_time]'][value='17:45']"
    assert_select "input[name='time_block[duration_minutes]'][value='4']"
    assert_select "input[name='time_block[locked]'][checked]"
  end

  test "stale block edit preserves draft and supplies the fresh lock" do
    block = existing_block
    stale_lock = block.lock_version
    block.update!(locked: true)
    before = block.reload.attributes

    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-06", time: "12:20", block_lock: stale_lock)

    assert_response :conflict
    assert_equal before, block.reload.attributes
    assert_select "[data-reschedule-conflict]"
    assert_select "input[name='time_block[local_date]'][value='2026-08-06']"
    assert_select "input[name='time_block[local_time]'][value='12:20']"
    assert_select "input[name='time_block[lock_version]'][value='#{block.lock_version}']"
  end

  test "timezone changed after opening the form is a conflict, not a silent shift" do
    block = existing_block
    original_timezone = @user.timezone
    before = block.attributes
    @user.update!(timezone: "Europe/Madrid")

    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-06", time: "09:00", timezone: original_timezone)

    assert_response :conflict
    assert_equal before, block.reload.attributes
    assert_select "[data-reschedule-conflict]"
    assert_select "input[name='time_block[timezone]'][value='#{original_timezone}']"
    assert_select "input[name='time_block[local_time]'][value='09:00']"
    assert_select "input[type='submit']", count: 0
  end

  test "reschedule overlap confirmation is bound to the block version and interval" do
    block = existing_block
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "Busy", start_time: zone.local(2026, 8, 3, 14), end_time: zone.local(2026, 8, 3, 16), event_type: "meeting", priority: "medium")

    patch task_time_block_url(@task, block), params: reschedule_params(block, time: "14:30")
    assert_response :unprocessable_entity
    signature = Nokogiri::HTML(response.body).at_css("input[name='time_block[overlap_signature]']")["value"]

    patch task_time_block_url(@task, block), params: reschedule_params(block, time: "15:00", overlap_signature: signature)
    assert_response :unprocessable_entity
    assert_equal "10:00", block.reload.starts_at.in_time_zone(@user.timezone).strftime("%H:%M")

    assert_no_difference "TimeBlock.count" do
      patch task_time_block_url(@task, block), params: reschedule_params(block, time: "14:30", overlap_signature: signature)
    end
    assert_response :redirect
    assert_equal "14:30", block.reload.starts_at.in_time_zone(@user.timezone).strftime("%H:%M")
  end

  test "a changed conflict set requires a fresh reschedule confirmation" do
    block = existing_block
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "First conflict", start_time: zone.local(2026, 8, 3, 14), end_time: zone.local(2026, 8, 3, 15), event_type: "meeting", priority: "medium")

    patch task_time_block_url(@task, block), params: reschedule_params(block, time: "14:15")
    signature = Nokogiri::HTML(response.body).at_css("input[name='time_block[overlap_signature]']")["value"]
    @user.calendar_events.create!(title: "New conflict", start_time: zone.local(2026, 8, 3, 14, 20), end_time: zone.local(2026, 8, 3, 14, 50), event_type: "meeting", priority: "medium")

    patch task_time_block_url(@task, block), params: reschedule_params(block, time: "14:15", overlap_signature: signature)

    assert_response :unprocessable_entity
    assert_select "[data-overlap-warning]"
    assert_equal "10:00", block.reload.starts_at.in_time_zone(@user.timezone).strftime("%H:%M")
  end

  test "a stale edit cannot resurrect an owned cancelled block" do
    block = existing_block
    stale_lock = block.lock_version
    block.update!(cancelled_at: Time.current)
    before = block.reload.attributes

    patch task_time_block_url(@task, block), params: reschedule_params(block, time: "13:00", block_lock: stale_lock)

    assert_response :conflict
    assert_equal before, block.reload.attributes
    assert_select "[data-reschedule-conflict]"
    assert_select "input[type='submit']", count: 0
  end

  test "malformed reschedule locks never write or raise" do
    block = existing_block
    before = block.attributes

    %i[task time_block].each do |target|
      [ nil, "", "-1", "999999999999999999999", "1x" ].each do |bad_lock|
        params = reschedule_params(block, time: "13:00")
        params[target][:lock_version] = bad_lock
        patch task_time_block_url(@task, block), params: params
        assert_response :conflict
        assert_equal before, block.reload.attributes
      end
    end
  end

  test "reschedule rejects DST gap and fold without normalizing" do
    @user.update!(timezone: "Europe/Madrid")
    block = existing_block
    before = block.attributes

    [ [ "2026-03-29", "02:30" ], [ "2026-10-25", "02:30" ] ].each do |date, time|
      patch task_time_block_url(@task, block), params: reschedule_params(block, date: date, time: time, timezone: "Europe/Madrid")
      assert_response :unprocessable_entity
      assert_equal before, block.reload.attributes
      assert_select "input[name='time_block[local_date]'][value='#{date}']"
      assert_select "input[name='time_block[local_time]'][value='#{time}']"
    end
  end

  test "reschedule excludes itself and treats touching boundaries as non-overlap" do
    block = existing_block
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(title: "Starts at block end", start_time: zone.local(2026, 8, 3, 10, 30), end_time: zone.local(2026, 8, 3, 11), event_type: "meeting", priority: "medium")

    patch task_time_block_url(@task, block), params: reschedule_params(block)

    assert_response :redirect
    assert_equal "10:00", block.reload.starts_at.in_time_zone(@user.timezone).strftime("%H:%M")
  end

  test "reschedule does not expose foreign, deleted, or mismatched blocks" do
    block = existing_block
    other_user = users(:moscow_user)
    other_task = other_user.tasks.create!(title: "Foreign task", owner_type: "user", status: "scheduled")
    foreign_block = other_task.time_blocks.create!(starts_at: Time.current + 2.days, ends_at: Time.current + 2.days + 30.minutes, previous_task_status: "inbox")

    patch task_time_block_url(@task, foreign_block), params: reschedule_params(block)
    assert_response :not_found

    @task.update!(deleted_at: Time.current)
    patch task_time_block_url(@task, block), params: reschedule_params(block)
    assert_response :not_found
  end

  test "return to queue still restores the exact previous status after reschedule" do
    block = existing_block

    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-07", time: "16:00", duration: "90")
    assert_response :redirect

    delete task_time_block_url(@task, block), params: {
      task: { lock_version: @task.reload.lock_version },
      time_block: { lock_version: block.reload.lock_version },
      view: "day",
      date: "2026-08-07"
    }

    assert_response :redirect
    assert_equal "inbox", @task.reload.status
    assert_predicate block.reload, :cancelled_at?
    assert_equal "inbox", block.previous_task_status
  end

  test "duration remains elapsed minutes across a DST transition" do
    @user.update!(timezone: "Europe/Madrid")
    block = existing_block

    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-03-29", time: "01:30", duration: "120", timezone: "Europe/Madrid")

    assert_response :redirect
    block.reload
    assert_equal 120.minutes, block.ends_at - block.starts_at
    assert_equal "01:30", block.starts_at.in_time_zone("Europe/Madrid").strftime("%H:%M")
    assert_equal "04:30", block.ends_at.in_time_zone("Europe/Madrid").strftime("%H:%M")
  end

  test "the immediate undo restores the exact previous interval in place" do
    block = existing_block
    before = block.attributes.slice("id", "task_id", "starts_at", "ends_at", "locked", "source", "previous_task_status", "cancelled_at")
    task_before = @task.reload.attributes.slice("status", "title", "lock_version")

    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-04", time: "14:15", duration: "90", locked: "1")
    follow_redirect!
    assert_response :success
    assert_select "form[action='#{undo_reschedule_task_time_block_path(@task, block)}']"
    token = Nokogiri::HTML(response.body).at_css("input[name='undo_token']")["value"]

    assert_no_difference "TimeBlock.count" do
      post undo_reschedule_task_time_block_url(@task, block), params: { undo_token: token }
    end

    assert_redirected_to calendar_events_path(view: "day", date: "2026-08-03")
    assert_equal before, block.reload.attributes.slice("id", "task_id", "starts_at", "ends_at", "locked", "source", "previous_task_status", "cancelled_at")
    assert_equal task_before, @task.reload.attributes.slice("status", "title", "lock_version")

    restored = block.attributes
    post undo_reschedule_task_time_block_url(@task, block), params: { undo_token: token }
    assert_response :conflict
    assert_equal restored, block.reload.attributes
  end

  test "a tampered undo token changes nothing" do
    block = existing_block
    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-04", time: "14:15", duration: "90")
    follow_redirect!
    token = Nokogiri::HTML(response.body).at_css("input[name='undo_token']")["value"]
    before = block.reload.attributes

    post undo_reschedule_task_time_block_url(@task, block), params: { undo_token: "#{token}x" }

    assert_response :conflict
    assert_equal before, block.reload.attributes
  end

  test "an undo token becomes stale after any later block edit" do
    block = existing_block
    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-04", time: "14:15", duration: "90")
    follow_redirect!
    token = Nokogiri::HTML(response.body).at_css("input[name='undo_token']")["value"]
    block.reload.update!(locked: true)
    before = block.reload.attributes

    post undo_reschedule_task_time_block_url(@task, block), params: { undo_token: token }

    assert_response :conflict
    assert_equal before, block.reload.attributes
  end

  test "undo rejects a previous interval whose conflict set changed" do
    block = existing_block
    patch task_time_block_url(@task, block), params: reschedule_params(block, date: "2026-08-04", time: "14:15", duration: "90")
    follow_redirect!
    token = Nokogiri::HTML(response.body).at_css("input[name='undo_token']")["value"]
    zone = Time.find_zone!(@user.timezone)
    @user.calendar_events.create!(
      title: "New conflict in old slot",
      start_time: zone.local(2026, 8, 3, 10, 5),
      end_time: zone.local(2026, 8, 3, 10, 20),
      event_type: "meeting",
      priority: "medium"
    )
    before = block.reload.attributes

    post undo_reschedule_task_time_block_url(@task, block), params: { undo_token: token }

    assert_response :conflict
    assert_equal before, block.reload.attributes
  end

  private

  def schedule_params(date: "2026-08-03", time: "10:00", duration: "30", lock_version: @task.lock_version, timezone: @user.timezone, overlap_signature: nil)
    {
      task: { lock_version: lock_version },
      time_block: {
        local_date: date,
        local_time: time,
        duration_minutes: duration,
        timezone: timezone,
        overlap_signature: overlap_signature
      },
      view: "month",
      date: date
    }
  end

  def existing_block
    zone = Time.find_zone!(@user.timezone)
    @task.update!(status: "scheduled")
    @task.time_blocks.create!(
      starts_at: zone.local(2026, 8, 3, 10),
      ends_at: zone.local(2026, 8, 3, 10, 30),
      source: "manual",
      previous_task_status: "inbox"
    )
  end

  def reschedule_params(block, date: "2026-08-03", time: "10:00", duration: "30", locked: "0", task_lock: @task.reload.lock_version, block_lock: block.reload.lock_version, timezone: @user.reload.timezone, overlap_signature: nil)
    {
      task: { lock_version: task_lock },
      time_block: {
        lock_version: block_lock,
        local_date: date,
        local_time: time,
        duration_minutes: duration,
        locked: locked,
        timezone: timezone,
        overlap_signature: overlap_signature
      },
      view: "day",
      date: date
    }
  end
end

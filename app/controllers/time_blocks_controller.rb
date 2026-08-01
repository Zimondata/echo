require "digest"

class TimeBlocksController < ApplicationController
  InvalidLockVersion = Class.new(StandardError)
  InvalidScheduleInput = Class.new(StandardError)
  TaskStateConflict = Class.new(StandardError)
  OverlapRequiresConfirmation = Class.new(StandardError)

  def create
    @task = current_user.tasks.active.find(params[:task_id])
    @schedule_input = schedule_input
    expected_lock = strict_lock_version(task_lock_version)
    ensure_current_timezone!
    starts_at, ends_at = parsed_interval!
    ensure_unscheduled!(@task)
    raise InvalidLockVersion unless @task.lock_version == expected_lock

    authorize_overlap!(starts_at, ends_at, expected_lock)

    TimeBlock.transaction do
      ensure_unscheduled!(@task)
      raise InvalidLockVersion unless @task.lock_version == expected_lock
      authorize_overlap!(starts_at, ends_at, expected_lock)

      previous_status = @task.status
      @task.lock_version = expected_lock
      @task.update!(status: "scheduled")
      @time_block = @task.time_blocks.create!(
        starts_at: starts_at,
        ends_at: ends_at,
        source: "manual",
        locked: schedule_params[:locked] == "1",
        previous_task_status: previous_status
      )
    end

    redirect_to calendar_events_path(view: "day", date: local_date(@time_block)),
                notice: "Задача запланирована"
  rescue OverlapRequiresConfirmation
    @schedule_errors = [ "Это время пересекается с другим блоком или событием. Проверь и подтверди наложение." ]
    render_schedule_frame(:unprocessable_entity)
  rescue InvalidScheduleInput => error
    @schedule_errors = [ error.message ]
    render_schedule_frame(:unprocessable_entity)
  rescue ActiveRecord::RecordInvalid => error
    @schedule_errors = error.record.errors.full_messages
    render_schedule_frame(:unprocessable_entity)
  rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique, InvalidLockVersion, TaskStateConflict
    @schedule_errors = [ "Задача изменилась. Проверь свежую версию и выбери время снова." ]
    @schedule_conflict = true
    render_schedule_frame(:conflict)
  end

  def edit
    @task = current_user.tasks.active.find(params[:task_id])
    @time_block = @task.time_blocks.active.find(params[:id])
    ensure_scheduled!(@task)
    @schedule_input = block_schedule_input(@time_block)
  end

  def update
    @task = current_user.tasks.active.find(params[:task_id])
    @time_block = @task.time_blocks.find(params[:id])
    @schedule_input = schedule_input
    expected_task_lock = strict_lock_version(task_lock_version)
    expected_block_lock = strict_lock_version(block_lock_version)
    ensure_current_timezone!
    starts_at, ends_at = parsed_interval!
    ensure_scheduled!(@task)
    raise InvalidLockVersion unless @task.lock_version == expected_task_lock
    raise InvalidLockVersion unless @time_block.lock_version == expected_block_lock

    authorize_overlap!(
      starts_at,
      ends_at,
      expected_task_lock,
      excluded_block: @time_block,
      expected_block_lock: expected_block_lock
    )

    TimeBlock.transaction do
      claim_task_for_reschedule!(expected_task_lock)
      @time_block.lock!
      ensure_scheduled!(@task)
      raise TaskStateConflict if @time_block.cancelled_at.present?
      raise InvalidLockVersion unless @time_block.lock_version == expected_block_lock

      ActiveSupport::Notifications.instrument(
        "time_block.reschedule.task_claimed",
        task_id: @task.id,
        time_block_id: @time_block.id
      )

      authorize_overlap!(
        starts_at,
        ends_at,
        expected_task_lock,
        excluded_block: @time_block,
        expected_block_lock: expected_block_lock
      )

      previous_schedule = {
        starts_at: @time_block.starts_at,
        ends_at: @time_block.ends_at,
        locked: @time_block.locked?
      }
      previous_conflicts = overlap_conflicts(
        previous_schedule[:starts_at],
        previous_schedule[:ends_at],
        excluded_block: @time_block
      )

      @time_block.lock_version = expected_block_lock
      @time_block.update!(
        starts_at: starts_at,
        ends_at: ends_at,
        locked: schedule_params[:locked] == "1"
      )
      @reschedule_undo_token = generate_reschedule_undo_token(
        previous_schedule,
        previous_conflicts,
        expected_task_lock
      )
    end

    redirect_to calendar_events_path(view: safe_view || "day", date: local_date(@time_block)),
                notice: "План обновлён",
                flash: {
                  time_block_reschedule_undo: @reschedule_undo_token,
                  time_block_reschedule_undo_id: @time_block.id
                }
  rescue OverlapRequiresConfirmation
    @schedule_errors = [ "Это время пересекается с другим блоком или событием. Проверь и подтверди наложение." ]
    render_edit_page(:unprocessable_entity)
  rescue InvalidScheduleInput => error
    @schedule_errors = [ error.message ]
    render_edit_page(:unprocessable_entity)
  rescue ActiveRecord::RecordInvalid => error
    @schedule_errors = error.record.errors.full_messages
    render_edit_page(:unprocessable_entity)
  rescue ActiveRecord::StaleObjectError, InvalidLockVersion, TaskStateConflict
    @schedule_errors = [ "План изменился. Проверь свежую версию и повтори перенос." ]
    @schedule_conflict = true
    render_edit_page(:conflict)
  end

  def undo_reschedule
    @task = current_user.tasks.active.find(params[:task_id])
    @time_block = @task.time_blocks.active.find(params[:id])
    payload = verified_reschedule_undo_payload
    expected_task_lock = strict_lock_version(payload[:task_lock_version])
    expected_block_lock = strict_lock_version(payload[:block_lock_version])
    previous_starts_at = Time.iso8601(payload[:starts_at])
    previous_ends_at = Time.iso8601(payload[:ends_at])
    raise TaskStateConflict unless previous_ends_at > previous_starts_at
    raise TaskStateConflict unless payload[:task_id] == @task.id && payload[:time_block_id] == @time_block.id
    raise TaskStateConflict unless payload[:timezone] == current_user.timezone

    TimeBlock.transaction do
      claim_task_for_reschedule!(expected_task_lock)
      @time_block.lock!
      raise TaskStateConflict if @time_block.cancelled_at.present?
      raise InvalidLockVersion unless @time_block.lock_version == expected_block_lock

      current_conflicts = overlap_conflicts(previous_starts_at, previous_ends_at, excluded_block: @time_block)
      raise TaskStateConflict unless conflict_set_digest(current_conflicts) == payload[:conflict_set_digest]

      @time_block.lock_version = expected_block_lock
      @time_block.update!(
        starts_at: previous_starts_at,
        ends_at: previous_ends_at,
        locked: payload[:locked]
      )
    end

    redirect_to calendar_events_path(view: "day", date: local_date(@time_block)),
                notice: "Перенос отменён"
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError, TypeError,
         ActiveRecord::StaleObjectError, InvalidLockVersion, TaskStateConflict
    render plain: "Перенос уже нельзя отменить. Открой свежий план.", status: :conflict
  end

  def destroy
    task = current_user.tasks.active.find(params[:task_id])
    block = task.time_blocks.active.find(params[:id])
    expected_task_lock = strict_lock_version(task_lock_version)
    expected_block_lock = strict_lock_version(block_lock_version)

    TimeBlock.transaction do
      raise TaskStateConflict unless task.status == "scheduled"
      raise InvalidLockVersion unless task.lock_version == expected_task_lock
      raise InvalidLockVersion unless block.lock_version == expected_block_lock

      block.lock_version = expected_block_lock
      block.update!(cancelled_at: Time.current)
      task.lock_version = expected_task_lock
      task.update!(status: block.previous_task_status)
    end

    redirect_to calendar_events_path(calendar_return_params), notice: "Задача возвращена в очередь"
  rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique, InvalidLockVersion, TaskStateConflict
    render plain: "План изменился. Обнови страницу и повтори отмену.", status: :conflict
  end

  private

  def schedule_params
    raw = params[:time_block]
    return ActionController::Parameters.new unless raw.is_a?(ActionController::Parameters)

    raw.permit(:local_date, :local_time, :duration_minutes, :locked, :timezone, :overlap_signature)
  end

  def schedule_input
    {
      local_date: schedule_params[:local_date].to_s,
      local_time: schedule_params[:local_time].to_s,
      duration_minutes: schedule_params[:duration_minutes].to_s,
      locked: schedule_params[:locked].to_s,
      timezone: schedule_params[:timezone].to_s,
      overlap_signature: schedule_params[:overlap_signature].to_s
    }
  end

  def task_lock_version
    raw = params[:task]
    raw[:lock_version] if raw.is_a?(ActionController::Parameters)
  end

  def block_lock_version
    raw = params[:time_block]
    raw[:lock_version] if raw.is_a?(ActionController::Parameters)
  end

  def strict_lock_version(value)
    string = value.to_s
    raise InvalidLockVersion unless string.match?(/\A\d+\z/)

    number = Integer(string, 10)
    raise InvalidLockVersion unless number.between?(0, (2**63) - 1)

    number
  end

  def parsed_interval!
    date = Date.iso8601(@schedule_input[:local_date])
    match = /\A([01]\d|2[0-3]):([0-5]\d)\z/.match(@schedule_input[:local_time])
    raise InvalidScheduleInput, "Укажи время в формате часы:минуты." unless match

    duration = Integer(@schedule_input[:duration_minutes], 10)
    raise InvalidScheduleInput, "Продолжительность должна быть от 5 до 720 минут." unless duration.between?(5, 720)

    zone = Time.find_zone!(current_user.timezone)
    wall_clock = Time.utc(date.year, date.month, date.day, match[1].to_i, match[2].to_i)
    periods = zone.tzinfo.periods_for_local(wall_clock)
    if periods.empty?
      raise InvalidScheduleInput, "Такого локального времени нет из-за перевода часов. Выбери соседнее время."
    end
    if periods.many?
      raise InvalidScheduleInput, "Это локальное время повторяется из-за перевода часов. Выбери соседнее время."
    end

    starts_at = Time.at(wall_clock.to_i - periods.first.utc_total_offset).utc
    [ starts_at, starts_at + duration.minutes ]
  rescue Date::Error, ArgumentError
    raise InvalidScheduleInput, "Проверь дату, время и продолжительность."
  rescue TZInfo::InvalidTimezoneIdentifier
    raise InvalidScheduleInput, "Часовой пояс профиля не распознан. Исправь его перед планированием."
  end

  def overlap_conflicts(starts_at, ends_at, excluded_block: nil)
    events = current_user.calendar_events.active
      .where("start_time < ?", ends_at)
      .where("all_day = ? OR end_time IS NULL OR end_time > ?", true, starts_at)
      .select { |event| event.start_time < ends_at && effective_event_end(event) > starts_at }

    blocks = TimeBlock.active.joins(:task)
      .merge(current_user.tasks.active)
      .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
    blocks = blocks.where.not(id: excluded_block.id) if excluded_block
    blocks = blocks.to_a

    event_keys = events.map do |event|
      [ "event", event.id, event.updated_at.to_f, event.start_time.to_f, effective_event_end(event).to_f ]
    end
    block_keys = blocks.map do |block|
      [ "block", block.id, block.updated_at.to_f, block.starts_at.to_f, block.ends_at.to_f ]
    end
    (event_keys + block_keys).sort
  end

  def effective_event_end(event)
    unless event.all_day?
      return event.end_time || event.start_time + 1.hour
    end

    zone = Time.find_zone!(current_user.timezone)
    local_date = event.start_time.in_time_zone(zone).to_date
    visible_day_end = zone.local(local_date.next_day.year, local_date.next_day.month, local_date.next_day.day)
    [ event.end_time, visible_day_end ].compact.max
  end

  def authorize_overlap!(starts_at, ends_at, expected_lock, excluded_block: nil, expected_block_lock: nil)
    conflicts = overlap_conflicts(starts_at, ends_at, excluded_block: excluded_block)
    return if conflicts.empty?

    digest = overlap_digest(starts_at, ends_at, expected_lock, conflicts, excluded_block, expected_block_lock)
    supplied_digest = overlap_verifier.verified(
      @schedule_input[:overlap_signature],
      purpose: :manual_time_block_overlap
    )
    return if supplied_digest == digest

    @overlap_warning = true
    @overlap_signature = overlap_verifier.generate(
      digest,
      purpose: :manual_time_block_overlap,
      expires_in: 15.minutes
    )
    raise OverlapRequiresConfirmation
  end

  def overlap_digest(starts_at, ends_at, expected_lock, conflicts, block = nil, expected_block_lock = nil)
    Digest::SHA256.hexdigest(
      [ @task.id, expected_lock, block&.id, expected_block_lock, starts_at.to_f, ends_at.to_f, conflicts ].to_json
    )
  end

  def overlap_verifier
    Rails.application.message_verifier("time-block-overlap")
  end

  def generate_reschedule_undo_token(previous_schedule, previous_conflicts, expected_task_lock)
    reschedule_undo_verifier.generate(
      {
        task_id: @task.id,
        time_block_id: @time_block.id,
        task_lock_version: expected_task_lock,
        block_lock_version: @time_block.lock_version,
        timezone: current_user.timezone,
        starts_at: previous_schedule[:starts_at].iso8601(6),
        ends_at: previous_schedule[:ends_at].iso8601(6),
        locked: previous_schedule[:locked],
        conflict_set_digest: conflict_set_digest(previous_conflicts)
      },
      purpose: :time_block_reschedule_undo,
      expires_in: 15.minutes
    )
  end

  def verified_reschedule_undo_payload
    payload = reschedule_undo_verifier.verify(
      params[:undo_token].to_s,
      purpose: :time_block_reschedule_undo
    )
    raise ActiveSupport::MessageVerifier::InvalidSignature unless payload.is_a?(Hash)

    payload.deep_symbolize_keys
  end

  def reschedule_undo_verifier
    Rails.application.message_verifier("time-block-reschedule-undo")
  end

  def conflict_set_digest(conflicts)
    Digest::SHA256.hexdigest(conflicts.to_json)
  end

  def ensure_unscheduled!(task)
    return if Task::UNSCHEDULED_STATUSES.include?(task.status)
    raise TaskStateConflict if task.status == "scheduled" && task.time_blocks.active.exists?

    raise ActiveRecord::RecordNotFound
  end

  def ensure_scheduled!(task)
    raise TaskStateConflict unless task.status == "scheduled"
  end

  def claim_task_for_reschedule!(expected_lock)
    claimed = current_user.tasks.active
      .where(id: @task.id, status: "scheduled", lock_version: expected_lock)
      .update_all(Arel.sql("lock_version = lock_version"))
    raise TaskStateConflict unless claimed == 1

    @task.reload
  end

  def ensure_current_timezone!
    raise TaskStateConflict unless @schedule_input[:timezone] == current_user.timezone
  end

  def block_schedule_input(block)
    zone = Time.find_zone!(current_user.timezone)
    local_start = block.starts_at.in_time_zone(zone)
    {
      local_date: local_start.to_date.iso8601,
      local_time: local_start.strftime("%H:%M"),
      duration_minutes: block.duration_minutes.to_s,
      locked: block.locked? ? "1" : "0",
      timezone: current_user.timezone,
      overlap_signature: ""
    }
  end

  def render_edit_page(status)
    @server_task = current_user.tasks.active.find(params[:task_id])
    @server_time_block = @server_task.time_blocks.find(params[:id])
    @can_retry = @server_task.status == "scheduled" &&
      @server_time_block.cancelled_at.nil? &&
      @schedule_input[:timezone] == current_user.timezone
    render "time_blocks/update", status: status
  end

  def render_schedule_frame(status)
    @server_task = current_user.tasks.active.find(params[:task_id])
    @submitted_task = @server_task
    @open_action = :schedule
    @calendar_view = safe_view
    @calendar_date = safe_date
    render "time_blocks/create", status: status
  end

  def local_date(block)
    block.starts_at.in_time_zone(Time.find_zone!(current_user.timezone)).to_date.iso8601
  end

  def calendar_return_params
    { view: safe_view || "day", date: safe_date }.compact
  end

  def safe_view
    params[:view] if CalendarEventsController::VIEWS.include?(params[:view])
  end

  def safe_date
    return if params[:date].blank?

    Date.iso8601(params[:date]).iso8601
  rescue Date::Error, TypeError
    nil
  end
end

class CalendarEventsController < ApplicationController
  VIEWS = %w[month week day].freeze

  before_action :set_calendar_event, only: %i[show edit update destroy]
  around_action :use_user_time_zone

  def index
    @user = current_user
    @calendar_view = VIEWS.include?(params[:view]) ? params[:view] : "month"
    @current_date = parsed_date(params[:date]) || legacy_month_date || user_today

    configure_date_range
    load_calendar_events
    load_time_blocks
    load_task_lane
    prepare_quick_create
    @rhythms = current_user.rhythms.active.ordered.includes(:rhythm_checkins)
    @rhythm_today = user_today
  end

  def show
  end

  def new
    @calendar_event = current_user.calendar_events.new(
      start_time: default_start_time,
      end_time: default_start_time + 1.hour,
      event_type: "plan",
      priority: "medium",
      life_category: "work"
    )
  end

  def create
    @calendar_event = current_user.calendar_events.new(calendar_event_params)

    if @calendar_event.save
      redirect_to calendar_return_path(@calendar_event), notice: "Событие создано"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if drag_move_params?
      return drag_failure_response("Страница устарела. Обнови календарь и повтори перенос.") unless drag_timezone_current?

      starts_at, ends_at = drag_interval
      return drag_failure_response("Новое время пересекается с другим блоком или событием.") if drag_conflict?(starts_at, ends_at)

      @calendar_event.lock_version = Integer(params.dig(:calendar_event, :lock_version), 10)
      @calendar_event.update!(start_time: starts_at, end_time: ends_at)
      return redirect_to calendar_events_path(date: starts_at.to_date.iso8601, view: drag_return_view),
                         notice: "Событие перенесено"
    end

    if @calendar_event.update(calendar_event_params)
      redirect_to calendar_events_path(date: local_event_date(@calendar_event), view: "day"),
                  notice: "Событие обновлено"
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError, ArgumentError, TypeError
    drag_failure_response("Событие изменилось или перенос устарел. Обнови календарь и повтори.")
  end

  def destroy
    @calendar_event.soft_delete!
    redirect_to calendar_events_path, notice: "Событие удалено"
  end

  private

  def configure_date_range
    case @calendar_view
    when "week"
      @range_start = @current_date.beginning_of_week(:monday)
      @range_end = @current_date.end_of_week(:monday)
      @previous_date = @current_date - 1.week
      @next_date = @current_date + 1.week
    when "day"
      @range_start = @current_date
      @range_end = @current_date
      @previous_date = @current_date - 1.day
      @next_date = @current_date + 1.day
    else
      month_start = @current_date.beginning_of_month
      month_end = @current_date.end_of_month
      @range_start = month_start.beginning_of_week(:monday)
      @range_end = month_end.end_of_week(:monday)
      @previous_date = @current_date - 1.month
      @next_date = @current_date + 1.month
    end

    @calendar_days = (@range_start..@range_end).to_a
  end

  def load_calendar_events
    range_start_time = user_zone.local(@range_start.year, @range_start.month, @range_start.day).beginning_of_day
    range_end_time = user_zone.local(@range_end.year, @range_end.month, @range_end.day).end_of_day

    @calendar_events = current_user.calendar_events.active
      .for_date_range(range_start_time, range_end_time)
      .order(:start_time)
      .to_a

    @events_by_date = Hash.new { |hash, date| hash[date] = [] }
    @calendar_events.each do |event|
      event_start_date = event.start_time.in_time_zone(user_zone).to_date
      event_end_date = ((event.end_time || event.start_time) - 0.000001).in_time_zone(user_zone).to_date
      visible_start = [ event_start_date, @range_start ].max
      visible_end = [ event_end_date, @range_end ].min
      next if visible_start > visible_end

      (visible_start..visible_end).each { |date| @events_by_date[date] << event }
    end

    @upcoming_events = current_user.calendar_events.active
      .where("start_time >= ?", Time.current)
      .order(:start_time)
      .limit(5)
  end

  def load_task_lane
    @task = current_user.tasks.new
    @unscheduled_tasks = current_user.tasks.unscheduled.order(:created_at)
  end

  def load_time_blocks
    range_start_time = user_zone.local(@range_start.year, @range_start.month, @range_start.day).beginning_of_day
    range_end_time = user_zone.local(@range_end.year, @range_end.month, @range_end.day).end_of_day
    @time_blocks = TimeBlock.active.joins(:task)
      .merge(current_user.tasks.active)
      .where("starts_at < ? AND ends_at > ?", range_end_time, range_start_time)
      .includes(:task)
      .order(:starts_at)
      .to_a
    @time_blocks_by_date = Hash.new { |hash, date| hash[date] = [] }
    @time_blocks.each do |block|
      block_start = block.starts_at.in_time_zone(user_zone).to_date
      block_end = (block.ends_at - 0.000001).in_time_zone(user_zone).to_date
      visible_start = [ block_start, @range_start ].max
      visible_end = [ block_end, @range_end ].min
      (visible_start..visible_end).each { |date| @time_blocks_by_date[date] << block }
    end
  end

  def prepare_quick_create
    start = user_zone.local(@current_date.year, @current_date.month, @current_date.day, 9)
    @quick_event = current_user.calendar_events.new(
      start_time: start,
      end_time: start + 1.hour,
      event_type: "plan",
      priority: "medium",
      life_category: "work"
    )
    @quick_note = current_user.entries.new(entry_type: "diary", occurred_at: start)
  end

  def set_calendar_event
    @calendar_event = current_user.calendar_events.active.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to calendar_events_path, alert: "Событие не найдено"
  end

  def calendar_event_params
    params.require(:calendar_event).permit(
      :title,
      :description,
      :start_time,
      :end_time,
      :event_type,
      :priority,
      :life_category,
      :all_day,
      :done,
      :reminder_minutes,
      :recurrence_pattern,
      :color,
      :lock_version
    )
  end

  def drag_return_view
    VIEWS.include?(params[:view]) ? params[:view] : "week"
  end

  def drag_failure_response(message)
    date = parsed_date(params[:date]) || parsed_date(params.dig(:calendar_event, :local_date)) ||
      @calendar_event.start_time.in_time_zone(user_zone).to_date
    redirect_to calendar_events_path(date: date.iso8601, view: drag_return_view), alert: message, status: :see_other
  end

  def drag_move_params?
    params.dig(:calendar_event, :local_date).present? || params.dig(:calendar_event, :local_time).present?
  end

  def drag_timezone_current?
    params.dig(:calendar_event, :timezone).to_s == current_user.timezone
  end

  def drag_interval
    raw = params.require(:calendar_event).permit(:local_date, :local_time, :duration_minutes)
    date = Date.iso8601(raw[:local_date].to_s)
    hour, minute = raw[:local_time].to_s.split(":", 2).map { |value| Integer(value, 10) }
    duration = Integer(raw[:duration_minutes], 10)
    raise ArgumentError unless hour.between?(0, 23) && minute.between?(0, 59) && duration.between?(5, 720)

    starts_at = user_zone.local(date.year, date.month, date.day, hour, minute)
    expected = "#{date.iso8601} #{format('%02d:%02d', hour, minute)}"
    raise ArgumentError unless starts_at.strftime("%F %H:%M") == expected

    [ starts_at, starts_at + duration.minutes ]
  end

  def drag_conflict?(starts_at, ends_at)
    event_conflict = current_user.calendar_events.active
      .where.not(id: @calendar_event.id)
      .where("start_time < ? AND COALESCE(end_time, start_time) > ?", ends_at, starts_at)
      .exists?
    return true if event_conflict

    TimeBlock.active.joins(:task)
      .merge(current_user.tasks.active)
      .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
      .exists?
  end

  def use_user_time_zone(&action)
    Time.use_zone(user_zone, &action)
  end

  def parsed_date(raw_date)
    return if raw_date.blank?

    Date.iso8601(raw_date)
  rescue Date::Error
    nil
  end

  def legacy_month_date
    return unless params[:year].present? && params[:month].present?

    Date.new(params[:year].to_i, params[:month].to_i, 1)
  rescue Date::Error, ArgumentError
    nil
  end

  def user_today
    Time.current.in_time_zone(user_zone).to_date
  end

  def user_zone
    @user_zone ||= ActiveSupport::TimeZone[current_user.timezone] || Time.zone
  end

  def default_start_time
    selected_date = parsed_date(params[:date])
    return user_zone.local(selected_date.year, selected_date.month, selected_date.day, 9) if selected_date

    now = Time.current.in_time_zone(user_zone)
    (now + 1.hour).change(min: 0, sec: 0)
  end

  def calendar_return_path(event)
    view = VIEWS.include?(params[:return_view]) ? params[:return_view] : "day"
    date = parsed_date(params[:return_date]) || event.start_time.in_time_zone(user_zone).to_date
    calendar_events_path(date: date.iso8601, view: view)
  end

  def local_event_date(event)
    event.start_time.in_time_zone(user_zone).to_date.iso8601
  end
end

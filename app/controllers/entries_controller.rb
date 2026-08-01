class EntriesController < ApplicationController
  class InvalidEntryTime < StandardError; end

  before_action :set_entry, only: [:show, :update, :destroy]
  around_action :use_user_time_zone

  def index
    @entries = current_user.entries.active.order(created_at: :desc).limit(20)
  end

  def create
    @entry = current_user.entries.new(entry_create_params)
    @entry.entry_type = "diary"
    @entry.status = "active"
    @entry.category = "life"
    @entry.dashboard_status = "processed"
    @entry.occurred_at ||= Time.current

    if @entry.save
      redirect_to entry_return_path, notice: "Запись сохранена"
    else
      @entries = current_user.entries.active.diaries.recent.limit(50)
      render :diary, status: :unprocessable_entity
    end
  rescue InvalidEntryTime => error
    @entry ||= current_user.entries.new(entry_type: "diary")
    @entry.errors.add(:occurred_at, error.message)
    @entries = current_user.entries.active.diaries.recent.limit(50)
    render :diary, status: :unprocessable_entity
  end

  def show
    # Entry is set by before_action
  end

  def update
    return unless @entry # Guard clause in case entry not found
    
    if @entry.update(entry_update_params)
      respond_to do |format|
        format.html { redirect_to entries_diary_path, notice: 'Запись обновлена' }
        format.json { render json: { success: true, message: 'Запись обновлена', entry_type: @entry.entry_type } }
      end
    else
      respond_to do |format|
        format.html { redirect_to entries_diary_path, alert: 'Ошибка при обновлении записи' }
        format.json { render json: { success: false, error: 'Ошибка при обновлении записи', errors: @entry.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def diary
    @user = current_user
    @entry = current_user.entries.new(entry_type: "diary")
    @entries = current_user.entries.active.diaries.recent.limit(50)
    render :diary
  end

  def ideas
    @user = current_user
    @entries = current_user.entries.active.where(entry_type: "idea").parent_entries.order(created_at: :desc).limit(20)
    
    # Генерируем smart notifications
    notifications_service = Ai::SmartNotificationsService.new(current_user)
    @smart_notifications = notifications_service.generate_notifications
    @weekly_insights = notifications_service.get_weekly_insights
    
    render :ideas
  end

  def plans
    @entries = current_user.entries.active.where(entry_type: "plan").order(created_at: :desc).limit(20)
    render :index
  end

  def destroy
    return unless @entry # Guard clause in case entry not found
    
    if @entry.update(status: 'deleted')
      respond_to do |format|
        format.html { redirect_to entries_diary_path, notice: 'Запись удалена' }
        format.json { render json: { success: true, message: 'Запись удалена' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to entries_diary_path, alert: 'Ошибка при удалении записи' }
        format.json { render json: { success: false, error: 'Ошибка при удалении записи' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_entry
    @entry = current_user.entries.active.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to entries_path, alert: 'Запись не найдена' }
      format.json { render json: { success: false, error: 'Запись не найдена' }, status: :not_found }
    end
  end

  def entry_return_path
    return diary_entries_path unless params[:return_to] == "calendar"

    view = %w[month week day].include?(params[:return_view]) ? params[:return_view] : "day"
    date = Date.iso8601(params[:return_date].to_s)
    calendar_events_path(date: date.iso8601, view: view)
  rescue Date::Error
    calendar_events_path(view: view)
  end

  def entry_create_params
    params.require(:entry).permit(:content, :occurred_at, :tags).tap do |permitted|
      permitted[:tags] = permitted[:tags].to_s.split(",").map(&:strip).reject(&:blank?).join(", ") if permitted.key?(:tags)
      permitted[:occurred_at] = parse_user_wall_clock(permitted[:occurred_at]) if permitted[:occurred_at].present?
    end
  end

  def parse_user_wall_clock(raw)
    match = raw.to_s.match(/\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})\z/)
    raise InvalidEntryTime, "имеет неверный формат" unless match

    year, month, day, hour, minute = match.captures.map { |value| Integer(value, 10) }
    local_time = Time.utc(year, month, day, hour, minute)
    periods = user_zone.tzinfo.periods_for_local(local_time)
    raise InvalidEntryTime, "попадает в переход времени; выбери другое время" unless periods.one?

    user_zone.local(year, month, day, hour, minute)
  rescue ArgumentError, TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
    raise InvalidEntryTime, "имеет неверное или неоднозначное локальное время"
  end

  def use_user_time_zone(&action)
    Time.use_zone(user_zone, &action)
  end

  def user_zone
    @user_zone ||= ActiveSupport::TimeZone[current_user.timezone] || Time.zone
  end

  def entry_update_params
    params.require(:entry).permit(:entry_type, :content, :status, :priority)
  end
end

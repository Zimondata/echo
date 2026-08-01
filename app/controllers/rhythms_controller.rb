class RhythmsController < ApplicationController
  before_action :set_rhythm, only: %i[update checkin return_to_rhythm]
  around_action :use_user_time_zone

  def index
    load_index
  end

  def create
    @rhythm = current_user.rhythms.new(rhythm_params.except(:active))
    if @rhythm.save
      redirect_to rhythms_path, notice: "Ритм сохранён"
    else
      load_index
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @rhythm.update(rhythm_params)
      redirect_to rhythms_path, notice: "Ритм обновлён"
    else
      load_index
      render :index, status: :unprocessable_entity
    end
  end

  def checkin
    state = params[:state].to_s
    return redirect_to rhythms_path, alert: "Неизвестная отметка" unless %w[full minimum skipped].include?(state)

    checkin = @rhythm.rhythm_checkins.find_or_initialize_by(local_date: user_today)
    if checkin.persisted? && checkin.state == "returned"
      redirect_to rhythms_path, alert: "Возврат уже сохранён и не перезаписывается."
      return
    end

    checkin.assign_attributes(state: state, previous_state: nil, returned_at: nil, note: params[:note].presence)
    checkin.save!
    redirect_to rhythms_path, notice: "Сегодня отмечено"
  end

  def return_to_rhythm
    @rhythm.with_lock do
      source = latest_returnable_checkin
      raise ActiveRecord::RecordNotFound unless source

      if source.local_date == user_today
        source.return!
      else
        @rhythm.rhythm_checkins.create!(
          local_date: user_today,
          state: "returned",
          previous_state: "skipped",
          returned_at: Time.current
        )
      end
    end
    redirect_to rhythms_path, notice: "Возвращение сохранено без обнуления."
  rescue ActiveRecord::RecordNotFound
    redirect_to rhythms_path, alert: "Последняя отметка не является пропуском."
  end

  private

  def load_index
    @rhythms = current_user.rhythms.ordered.includes(:rhythm_checkins)
    @rhythm ||= current_user.rhythms.new(position: @rhythms.size)
    @active_count = @rhythms.count(&:active?)
    @today = user_today
    @return_sources = @rhythms.each_with_object({}) do |rhythm, sources|
      latest = rhythm.rhythm_checkins.select { |checkin| checkin.local_date <= @today }.max_by(&:local_date)
      sources[rhythm.id] = latest if latest&.state == "skipped"
    end
  end

  def set_rhythm
    @rhythm = current_user.rhythms.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to rhythms_path, alert: "Ритм не найден"
  end

  def rhythm_params
    params.require(:rhythm).permit(:name, :full_version, :minimum_version, :active)
  end

  def latest_returnable_checkin
    today_checkin = @rhythm.rhythm_checkins.find_by(local_date: user_today)
    return today_checkin if today_checkin&.state == "skipped"
    return nil if today_checkin

    latest = @rhythm.rhythm_checkins.where("local_date < ?", user_today).order(local_date: :desc).first
    latest if latest&.state == "skipped"
  end

  def use_user_time_zone(&action)
    Time.use_zone(user_zone, &action)
  end

  def user_zone
    @user_zone ||= ActiveSupport::TimeZone[current_user.timezone] || Time.zone
  end

  def user_today
    Time.current.in_time_zone(user_zone).to_date
  end
end

class RemindersController < ApplicationController
  class InvalidReminderTime < StandardError; end

  before_action :set_reminder, only: [ :destroy, :snooze ]
  around_action :use_user_time_zone

  def index
    @pending_reminders = current_user.reminders.pending.order(:remind_at)
    @sent_reminders = current_user.reminders.where(status: "sent").order(remind_at: :desc).limit(20)

    # Group by type
    @regular_reminders = @pending_reminders.where(reminder_type: "one_time")
    @smart_reminders = @pending_reminders.smart.by_priority

    # Stats
    @total_reminders = current_user.reminders.count
    @smart_total = current_user.reminders.smart.count
    @helpful_count = current_user.reminders.smart.where(user_feedback: "helpful").count
    @new_reminder = current_user.reminders.new(reminder_type: "one_time", priority: "medium", remind_at: 1.hour.from_now)
  end

  def create
    @reminder = current_user.reminders.new(reminder_attributes)
    @reminder.reminder_type = "one_time"
    @reminder.status = "pending"
    if @reminder.save
      redirect_to reminders_path, notice: "Напоминание создано"
    else
      @pending_reminders = current_user.reminders.pending.order(:remind_at)
      @sent_reminders = current_user.reminders.where(status: "sent").order(remind_at: :desc).limit(20)
      @regular_reminders = @pending_reminders.where(reminder_type: "one_time")
      @smart_reminders = @pending_reminders.smart.by_priority
      @total_reminders = current_user.reminders.count
      @smart_total = current_user.reminders.smart.count
      @helpful_count = current_user.reminders.smart.where(user_feedback: "helpful").count
      @new_reminder = @reminder
      render :index, status: :unprocessable_entity
    end
  rescue InvalidReminderTime => error
    @reminder ||= current_user.reminders.new
    @reminder.errors.add(:remind_at, error.message)
    load_index_data
    @new_reminder = @reminder
    render :index, status: :unprocessable_entity
  end

  def destroy
    @reminder.cancel!
    redirect_to reminders_path, notice: 'Напоминание отменено'
  end

  def snooze
    duration = params[:duration]&.to_i || 60
    @reminder.snooze!(duration)
    redirect_to reminders_path, notice: "Напоминание отложено на #{duration} минут"
  end

  private

  def reminder_attributes
    attributes = params.require(:reminder).permit(:message, :priority, :recurrence_rule).to_h
    attributes["remind_at"] = parse_user_wall_clock(params.dig(:reminder, :remind_at))
    attributes
  end

  def parse_user_wall_clock(raw)
    match = raw.to_s.match(/\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})\z/)
    raise InvalidReminderTime, "имеет неверный формат" unless match

    year, month, day, hour, minute = match.captures.map { |value| Integer(value, 10) }
    local_time = Time.utc(year, month, day, hour, minute)
    periods = user_zone.tzinfo.periods_for_local(local_time)
    raise InvalidReminderTime, "попадает в переход времени; выбери другое время" unless periods.one?

    user_zone.local(year, month, day, hour, minute)
  rescue ArgumentError, TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
    raise InvalidReminderTime, "имеет неверное или неоднозначное локальное время"
  end

  def load_index_data
    @pending_reminders = current_user.reminders.pending.order(:remind_at)
    @sent_reminders = current_user.reminders.where(status: "sent").order(remind_at: :desc).limit(20)
    @regular_reminders = @pending_reminders.where(reminder_type: "one_time")
    @smart_reminders = @pending_reminders.smart.by_priority
    @total_reminders = current_user.reminders.count
    @smart_total = current_user.reminders.smart.count
    @helpful_count = current_user.reminders.smart.where(user_feedback: "helpful").count
  end

  def use_user_time_zone(&action)
    Time.use_zone(user_zone, &action)
  end

  def user_zone
    @user_zone ||= ActiveSupport::TimeZone[current_user.timezone] || Time.zone
  end

  def set_reminder
    @reminder = current_user.reminders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to reminders_path, alert: 'Напоминание не найдено'
  end
end

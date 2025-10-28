class RemindersController < ApplicationController
  before_action :set_reminder, only: [:show, :destroy, :snooze]

  def index
    @pending_reminders = current_user.reminders.pending.order(:remind_at)
    @sent_reminders = current_user.reminders.where(status: "sent").order(remind_at: :desc).limit(20)

    # Group by type
    @regular_reminders = @pending_reminders.regular
    @smart_reminders = @pending_reminders.smart.by_priority

    # Stats
    @total_reminders = current_user.reminders.count
    @smart_total = current_user.reminders.smart.count
    @helpful_count = current_user.reminders.smart.where(user_feedback: "helpful").count
  end

  def show
    # Reminder is set by before_action
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

  def set_reminder
    @reminder = current_user.reminders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to reminders_path, alert: 'Напоминание не найдено'
  end
end

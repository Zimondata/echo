class RemindersController < ApplicationController
  before_action :set_reminder, only: [:show]

  def index
    @pending_reminders = current_user.reminders.where(status: "pending").order(remind_at: :asc)
    @sent_reminders = current_user.reminders.where(status: "sent").order(remind_at: :desc).limit(20)
  end

  def show
    # Reminder is set by before_action
  end

  private

  def set_reminder
    @reminder = current_user.reminders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to reminders_path, alert: 'Напоминание не найдено'
  end
end

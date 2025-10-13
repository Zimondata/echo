class RemindersController < ApplicationController
  def index
    @user = User.first
    @pending_reminders = @user.reminders.where(status: "pending").order(remind_at: :asc)
    @sent_reminders = @user.reminders.where(status: "sent").order(remind_at: :desc).limit(20)
  end

  def show
    @reminder = Reminder.find(params[:id])
  end
end

class DashboardController < ApplicationController
  def index
    @user = User.first # Временно берем первого пользователя

    # Статистика
    @total_entries = @user.entries.count
    @diary_count = @user.entries.where(entry_type: "diary").count
    @ideas_count = @user.entries.where(entry_type: "idea").count
    @plans_count = @user.entries.where(entry_type: "plan").count

    # Последние записи
    @recent_entries = @user.entries.order(created_at: :desc).limit(5)

    # Ближайшие события
    @upcoming_events = @user.calendar_events
                            .where("start_time >= ?", Time.current)
                            .order(start_time: :asc)
                            .limit(5)

    # Активные напоминания
    @pending_reminders = @user.reminders
                              .where(status: "pending")
                              .where("remind_at >= ?", Time.current)
                              .order(remind_at: :asc)
                              .limit(5)
  end
end

class CalendarEventsController < ApplicationController
  def index
    @user = User.first
    @calendar_events = @user.calendar_events.order(start_time: :asc)

    # Группируем по месяцам для календаря
    @events_by_month = @calendar_events.group_by { |e| e.start_time.beginning_of_month }
  end

  def show
    @calendar_event = CalendarEvent.find(params[:id])
  end
end

class CalendarEventsController < ApplicationController
  before_action :set_calendar_event, only: [:show]

  def index
    @calendar_events = current_user.calendar_events.order(start_time: :asc)

    # Группируем по месяцам для календаря
    @events_by_month = @calendar_events.group_by { |e| e.start_time.beginning_of_month }
  end

  def show
    # Calendar event is set by before_action
  end

  private

  def set_calendar_event
    @calendar_event = current_user.calendar_events.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to calendar_events_path, alert: 'Событие не найдено'
  end
end

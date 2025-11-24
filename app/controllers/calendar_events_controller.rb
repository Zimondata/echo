class CalendarEventsController < ApplicationController
  before_action :set_calendar_event, only: [:show]

  def index
    @user = current_user

    # Получаем месяц и год из параметров или используем текущие
    @current_date = if params[:year] && params[:month]
      Date.new(params[:year].to_i, params[:month].to_i, 1)
    else
      Date.current
    end

    # Получаем начало и конец месяца для отображения календаря
    start_of_month = @current_date.beginning_of_month
    end_of_month = @current_date.end_of_month

    # Получаем начало и конец календарной сетки (включая дни из предыдущего/следующего месяца)
    @start_of_calendar = start_of_month.beginning_of_week(:monday)
    @end_of_calendar = end_of_month.end_of_week(:monday)

    # Получаем события для текущего месяца (с небольшим запасом)
    @calendar_events = current_user.calendar_events
      .where('start_time >= ? AND start_time <= ?',
             @start_of_calendar.beginning_of_day,
             @end_of_calendar.end_of_day)
      .order(start_time: :asc)

    # Группируем по месяцам для календаря
    @events_by_month = @calendar_events.group_by { |e| e.start_time.beginning_of_month }

    # Вычисляем предыдущий и следующий месяц для навигации
    @prev_month = @current_date - 1.month
    @next_month = @current_date + 1.month
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

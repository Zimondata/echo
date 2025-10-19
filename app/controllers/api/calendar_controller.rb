class Api::CalendarController < Api::BaseController
  before_action :set_calendar_event, only: [:show, :update, :destroy, :toggle_done, :move]

  # GET /api/calendar/events
  def index
    events = current_user.calendar_events.active

    # Filter by date range
    if params[:start_date] && params[:end_date]
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      events = events.for_date_range(start_date, end_date)
    end

    # Filter by view type
    case params[:view]
    when 'week'
      date = params[:date] ? Date.parse(params[:date]) : Date.current
      events = events.for_week(date)
    when 'month'
      date = params[:date] ? Date.parse(params[:date]) : Date.current
      events = events.for_month(date)
    end

    # Filter by category
    events = events.by_category(params[:category]) if params[:category].present?

    # Filter by completion status
    case params[:status]
    when 'completed'
      events = events.completed
    when 'pending'
      events = events.pending
    end

    render json: {
      events: events.includes(:entry, :user).map { |event| serialize_event(event) },
      categories: CalendarEvent::CATEGORIES,
      meta: {
        total_count: events.count,
        view: params[:view],
        date_range: {
          start: events.minimum(:start_time),
          end: events.maximum(:start_time)
        }
      }
    }
  end

  # GET /api/calendar/events/:id
  def show
    render json: { event: serialize_event(@calendar_event) }
  end

  # POST /api/calendar/events
  def create
    @calendar_event = current_user.calendar_events.build(calendar_event_params)

    if @calendar_event.save
      broadcast_calendar_update('created', @calendar_event)
      render json: { 
        event: serialize_event(@calendar_event),
        message: 'Событие успешно создано'
      }, status: :created
    else
      render json: { 
        errors: @calendar_event.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/calendar/events/:id
  def update
    if @calendar_event.update(calendar_event_params)
      broadcast_calendar_update('updated', @calendar_event)
      render json: { 
        event: serialize_event(@calendar_event),
        message: 'Событие успешно обновлено'
      }
    else
      render json: { 
        errors: @calendar_event.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/calendar/events/:id
  def destroy
    @calendar_event.soft_delete!
    broadcast_calendar_update('deleted', @calendar_event)
    render json: { message: 'Событие удалено' }
  end

  # PATCH /api/calendar/events/:id/toggle_done
  def toggle_done
    @calendar_event.toggle_done!
    broadcast_calendar_update('toggled', @calendar_event)
    render json: { 
      event: serialize_event(@calendar_event),
      message: @calendar_event.done? ? 'Событие отмечено как выполненное' : 'Событие отмечено как невыполненное'
    }
  end

  # PATCH /api/calendar/events/:id/move
  def move
    if params[:new_date]
      # Moving to a new date (drag & drop)
      new_date = Date.parse(params[:new_date])
      
      # Keep the same time but change the date
      current_time = @calendar_event.start_time
      new_start_time = new_date.beginning_of_day + 
                      current_time.hour.hours + 
                      current_time.min.minutes + 
                      current_time.sec.seconds
      
      # Calculate duration to maintain it when moving
      duration = @calendar_event.end_time ? (@calendar_event.end_time - @calendar_event.start_time) : nil
      new_end_time = duration ? new_start_time + duration : nil
      
    elsif params[:start_time]
      # Moving to specific time
      new_start_time = Time.zone.parse(params[:start_time])
      new_end_time = params[:end_time] ? Time.zone.parse(params[:end_time]) : nil
      
      # Calculate duration to maintain it when moving
      duration = @calendar_event.end_time ? (@calendar_event.end_time - @calendar_event.start_time) : nil
      new_end_time ||= (duration ? new_start_time + duration : nil)
    else
      render json: { errors: ['Необходимо указать new_date или start_time'] }, status: :bad_request
      return
    end
    
    @calendar_event.start_time = new_start_time
    @calendar_event.end_time = new_end_time

    if @calendar_event.save
      broadcast_calendar_update('moved', @calendar_event)
      render json: { 
        event: serialize_event(@calendar_event),
        message: 'Событие перенесено'
      }
    else
      render json: { 
        errors: @calendar_event.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  # GET /api/calendar/categories
  def categories
    render json: {
      categories: CalendarEvent::CATEGORIES.map do |key, info|
        {
          id: key,
          name: info[:label],
          color: info[:color],
          count: current_user.calendar_events.active.by_category(key).count
        }
      end
    }
  end

  # GET /api/calendar/upcoming
  def upcoming
    limit = params[:limit]&.to_i || 5
    events = current_user.calendar_events.upcoming.pending.limit(limit)
    
    render json: {
      events: events.map { |event| serialize_event(event) }
    }
  end

  # GET /api/calendar/stats
  def stats
    today = Date.current
    
    render json: {
      today: current_user.calendar_events.active.where(start_time: today.beginning_of_day..today.end_of_day).count,
      this_week: current_user.calendar_events.for_week(today).count,
      this_month: current_user.calendar_events.for_month(today).count,
      completed_this_week: current_user.calendar_events.for_week(today).completed.count,
      pending_reminders: current_user.calendar_events.reminder_pending.count,
      by_category: CalendarEvent::CATEGORIES.keys.map do |category|
        {
          category: category,
          count: current_user.calendar_events.active.by_category(category).count
        }
      end
    }
  end

  private

  def set_calendar_event
    @calendar_event = current_user.calendar_events.active.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Event not found' }, status: :not_found
  end

  def calendar_event_params
    params.require(:calendar_event).permit(
      :title, :description, :start_time, :end_time, :event_type,
      :all_day, :priority, :color, :reminder_minutes,
      tags: []
    )
  end

  def serialize_event(event)
    {
      id: event.id,
      title: event.title,
      description: event.description,
      start_time: event.start_time.iso8601,
      end_time: event.end_time&.iso8601,
      start_date: event.start_date.iso8601,
      end_date: event.end_date.iso8601,
      event_type: event.event_type,
      category_info: event.category_info,
      all_day: event.all_day?,
      done: event.done?,
      priority: event.priority,
      color: event.display_color,
      tags: event.tags,
      duration_minutes: event.duration_minutes,
      reminder_minutes: event.reminder_minutes,
      reminder_time: event.reminder_time&.iso8601,
      spans_multiple_days: event.spans_multiple_days?,
      created_at: event.created_at.iso8601,
      updated_at: event.updated_at.iso8601
    }
  end

  def broadcast_calendar_update(action, event)
    ActionCable.server.broadcast(
      "calendar_#{current_user.id}",
      {
        type: "calendar:event:#{action}",
        data: {
          event: serialize_event(event),
          user_id: current_user.id,
          timestamp: Time.current.iso8601
        }
      }
    )
  end
end
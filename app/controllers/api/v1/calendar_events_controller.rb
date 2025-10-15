class Api::V1::CalendarEventsController < Api::BaseController
  before_action :find_calendar_event, only: [:show, :update, :destroy, :toggle_done]

  def index
    events = current_user.calendar_events.active.order(:start_time)

    # Filters
    events = events.where('start_time >= ?', params[:start_date]) if params[:start_date].present?
    events = events.where('start_time <= ?', params[:end_date]) if params[:end_date].present?
    events = events.where(event_type: params[:event_type]) if params[:event_type].present?
    events = events.where(done: params[:done]) if params[:done].present?

    paginated = paginate(events)
    paginated[:data] = paginated[:data].map { |event| serialize_calendar_event(event) }

    success_response(paginated)
  end

  def show
    success_response(serialize_calendar_event_full(@calendar_event))
  end

  def create
    event = current_user.calendar_events.build(calendar_event_params)
    
    if event.save
      success_response(serialize_calendar_event_full(event), message: "Calendar event created successfully", status: :created)
    else
      error_response("Failed to create calendar event", status: :unprocessable_entity, details: event.errors.full_messages)
    end
  end

  def update
    if @calendar_event.update(calendar_event_params)
      success_response(serialize_calendar_event_full(@calendar_event), message: "Calendar event updated successfully")
    else
      error_response("Failed to update calendar event", status: :unprocessable_entity, details: @calendar_event.errors.full_messages)
    end
  end

  def destroy
    @calendar_event.soft_delete!
    success_response({ id: @calendar_event.id }, message: "Calendar event deleted successfully")
  end

  def toggle_done
    @calendar_event.toggle_done!
    success_response(serialize_calendar_event_full(@calendar_event), message: "Event status updated")
  end

  # Calendar statistics
  def stats
    stats = {
      total_events: current_user.calendar_events.active.count,
      upcoming_events: current_user.calendar_events.upcoming.count,
      completed_events: current_user.calendar_events.completed.count,
      pending_events: current_user.calendar_events.pending.count,
      this_week_events: current_user.calendar_events.for_week.count,
      this_month_events: current_user.calendar_events.for_month.count
    }

    success_response(stats)
  end

  private

  def find_calendar_event
    @calendar_event = current_user.calendar_events.find(params[:id])
  end

  def calendar_event_params
    params.require(:calendar_event).permit(
      :title, :description, :start_time, :end_time, :event_type, :all_day,
      :priority, :color, :reminder_minutes, tags: [], metadata: {}
    )
  end

  def serialize_calendar_event(event)
    {
      id: event.id,
      title: event.title,
      description: event.description,
      start_time: event.start_time,
      end_time: event.end_time,
      event_type: event.event_type,
      all_day: event.all_day?,
      priority: event.priority,
      color: event.display_color,
      done: event.done?,
      reminder_minutes: event.reminder_minutes,
      duration_minutes: event.duration_minutes,
      created_at: event.created_at,
      updated_at: event.updated_at
    }
  end

  def serialize_calendar_event_full(event)
    {
      id: event.id,
      title: event.title,
      description: event.description,
      start_time: event.start_time,
      end_time: event.end_time,
      event_type: event.event_type,
      all_day: event.all_day?,
      priority: event.priority,
      color: event.display_color,
      tags: event.tags,
      done: event.done?,
      reminder_minutes: event.reminder_minutes,
      reminder_sent: event.reminder_sent?,
      duration_minutes: event.duration_minutes,
      metadata: event.metadata,
      created_at: event.created_at,
      updated_at: event.updated_at,
      entry: event.entry ? serialize_entry(event.entry) : nil
    }
  end

  def serialize_entry(entry)
    {
      id: entry.id,
      entry_type: entry.entry_type,
      content: entry.content.truncate(100),
      category: entry.category,
      created_at: entry.created_at
    }
  end
end
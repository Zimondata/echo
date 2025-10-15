class Api::V1::DashboardController < Api::BaseController
  def overview
    stats = {
      entries: {
        total: current_user.entries.active.count,
        new: current_user.entries.active.new_items.count,
        needs_attention: current_user.entries.active.needs_attention.count,
        by_type: {
          diary: current_user.entries.active.diaries.count,
          ideas: current_user.entries.active.ideas.count,
          plans: current_user.entries.active.plans.count
        },
        by_category: category_stats
      },
      calendar: {
        upcoming_events: current_user.calendar_events
          .where('start_time >= ?', Time.current)
          .count,
        today_events: current_user.calendar_events
          .where(start_time: Date.current.beginning_of_day..Date.current.end_of_day)
          .count,
        this_week_events: current_user.calendar_events
          .where(start_time: Date.current.beginning_of_week..Date.current.end_of_week)
          .count
      },
      reminders: {
        pending: current_user.reminders.where(status: 'pending').count,
        today: current_user.reminders
          .where(status: 'pending')
          .where('remind_at::date = ?', Date.current)
          .count,
        overdue: current_user.reminders
          .where(status: 'pending')
          .where('remind_at < ?', Time.current)
          .count
      }
    }

    recent_activity = {
      recent_entries: recent_entries_data,
      upcoming_events: upcoming_events_data,
      pending_reminders: pending_reminders_data,
      insights: insights_data
    }

    success_response({
      stats: stats,
      recent_activity: recent_activity
    })
  end

  def inbox
    entries = current_user.entries.active.inbox.recent
    paginated = paginate(entries, per_page: 20)
    
    paginated[:data] = paginated[:data].map do |entry|
      serialize_entry(entry)
    end

    success_response(paginated)
  end

  def needs_attention
    entries = current_user.entries.active.needs_attention.recent
    paginated = paginate(entries, per_page: 20)
    
    paginated[:data] = paginated[:data].map do |entry|
      serialize_entry(entry)
    end

    success_response(paginated)
  end

  private

  def category_stats
    current_user.entries.active
      .group(:category)
      .count
  end

  def recent_entries_data
    current_user.entries.active
      .recent
      .limit(10)
      .map { |entry| serialize_entry(entry) }
  end

  def upcoming_events_data
    current_user.calendar_events
      .where('start_time >= ?', Time.current)
      .order(:start_time)
      .limit(5)
      .map { |event| serialize_calendar_event(event) }
  end

  def pending_reminders_data
    current_user.reminders
      .where(status: 'pending')
      .where('remind_at >= ?', Time.current)
      .order(:remind_at)
      .limit(5)
      .map { |reminder| serialize_reminder(reminder) }
  end

  def insights_data
    current_user.insights
      .active
      .recent
      .limit(3)
      .map { |insight| serialize_insight(insight) }
  end

  def serialize_entry(entry)
    {
      id: entry.id,
      entry_type: entry.entry_type,
      content: entry.content,
      category: entry.category,
      dashboard_status: entry.dashboard_status,
      priority: entry.priority,
      tags: entry.tag_list,
      insights: entry.insights,
      occurred_at: entry.occurred_at,
      created_at: entry.created_at,
      has_audio: entry.audio_file_id.present?,
      has_transcript: entry.transcript.present?
    }
  end

  def serialize_calendar_event(event)
    {
      id: event.id,
      title: event.title,
      description: event.description,
      start_time: event.start_time,
      end_time: event.end_time,
      event_type: event.event_type,
      google_synced: event.google_event_id.present?
    }
  end

  def serialize_reminder(reminder)
    {
      id: reminder.id,
      message: reminder.message,
      remind_at: reminder.remind_at,
      reminder_type: reminder.reminder_type,
      status: reminder.status
    }
  end

  def serialize_insight(insight)
    {
      id: insight.id,
      insight_type: insight.insight_type,
      title: insight.title,
      content: insight.content,
      data: insight.data,
      generated_at: insight.generated_at
    }
  end
end
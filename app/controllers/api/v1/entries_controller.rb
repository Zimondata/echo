class Api::V1::EntriesController < Api::BaseController
  before_action :find_entry, only: [:show, :update, :categorize, :add_tags]

  def index
    entries = current_user.entries.active

    # Фильтры
    entries = entries.where(entry_type: params[:type]) if params[:type].present?
    entries = entries.by_category(params[:category]) if params[:category].present?
    entries = entries.where(dashboard_status: params[:status]) if params[:status].present?
    
    # Поиск
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      entries = entries.where("content ILIKE ? OR transcript ILIKE ?", search_term, search_term)
    end

    # Сортировка
    case params[:sort]
    when 'priority'
      entries = entries.by_priority
    when 'created_at'
      entries = entries.order(:created_at)
    else
      entries = entries.recent
    end

    paginated = paginate(entries)
    paginated[:data] = paginated[:data].map { |entry| serialize_entry(entry) }

    success_response(paginated)
  end

  def show
    success_response(serialize_entry_full(@entry))
  end

  def update
    if @entry.update(entry_update_params)
      success_response(serialize_entry_full(@entry), message: "Entry updated successfully")
    else
      error_response("Failed to update entry", status: :unprocessable_entity, details: @entry.errors)
    end
  end

  def categorize
    if @entry.update(category: params[:category])
      @entry.update(dashboard_status: 'triaged') if @entry.new?
      success_response(serialize_entry(@entry), message: "Entry categorized successfully")
    else
      error_response("Failed to categorize entry", status: :unprocessable_entity, details: @entry.errors)
    end
  end

  def add_tags
    tags_to_add = Array(params[:tags]).map(&:strip).reject(&:blank?)
    
    tags_to_add.each { |tag| @entry.add_tag(tag) }
    
    if @entry.save
      success_response(serialize_entry(@entry), message: "Tags added successfully")
    else
      error_response("Failed to add tags", status: :unprocessable_entity, details: @entry.errors)
    end
  end

  def bulk_update
    entry_ids = params[:entry_ids] || []
    entries = current_user.entries.where(id: entry_ids)
    
    update_params = {}
    update_params[:category] = params[:category] if params[:category].present?
    update_params[:dashboard_status] = params[:dashboard_status] if params[:dashboard_status].present?
    update_params[:priority] = params[:priority] if params[:priority].present?
    
    if entries.update_all(update_params)
      success_response({ updated_count: entries.count }, message: "Entries updated successfully")
    else
      error_response("Failed to update entries")
    end
  end

  def similar
    @entry = current_user.entries.find(params[:id])
    
    if @entry.embedding.nil?
      return error_response("Entry has no embedding for similarity search")
    end

    similar_entries = @entry.nearest_neighbors(:embedding, distance: "cosine")
                           .where.not(id: @entry.id)
                           .limit(10)

    success_response({
      similar_entries: similar_entries.map { |entry| serialize_entry(entry) }
    })
  end

  def stats
    stats = {
      total: current_user.entries.active.count,
      by_type: current_user.entries.active.group(:entry_type).count,
      by_category: current_user.entries.active.group(:category).count,
      by_status: current_user.entries.active.group(:dashboard_status).count,
      recent_activity: {
        today: current_user.entries.active.where('created_at >= ?', 1.day.ago).count,
        this_week: current_user.entries.active.where('created_at >= ?', 1.week.ago).count,
        this_month: current_user.entries.active.where('created_at >= ?', 1.month.ago).count
      },
      top_tags: top_tags
    }

    success_response(stats)
  end

  private

  def find_entry
    @entry = current_user.entries.find(params[:id])
  end

  def entry_update_params
    params.require(:entry).permit(:content, :entry_type, :category, :dashboard_status, :priority, :tags, :status)
  end

  def serialize_entry(entry)
    {
      id: entry.id,
      entry_type: entry.entry_type,
      content: entry.content.truncate(200),
      category: entry.category,
      dashboard_status: entry.dashboard_status,
      priority: entry.priority,
      tags: entry.tag_list,
      occurred_at: entry.occurred_at,
      created_at: entry.created_at,
      has_audio: entry.audio_file_id.present?,
      has_transcript: entry.transcript.present?,
      has_calendar_event: entry.calendar_event.present?,
      has_reminders: entry.reminders.any?
    }
  end

  def serialize_entry_full(entry)
    {
      id: entry.id,
      entry_type: entry.entry_type,
      content: entry.content,
      transcript: entry.transcript,
      audio_url: entry.audio_url,
      category: entry.category,
      dashboard_status: entry.dashboard_status,
      priority: entry.priority,
      tags: entry.tag_list,
      insights: entry.insights,
      metadata: entry.metadata,
      status: entry.status,
      occurred_at: entry.occurred_at,
      processed_at: entry.processed_at,
      created_at: entry.created_at,
      updated_at: entry.updated_at,
      calendar_event: entry.calendar_event ? serialize_calendar_event(entry.calendar_event) : nil,
      reminders: entry.reminders.map { |r| serialize_reminder(r) }
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
      google_event_id: event.google_event_id
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

  def top_tags
    # Собираем все теги и считаем их частоту
    tag_counts = Hash.new(0)
    
    current_user.entries.active.where.not(tags: [nil, '']).find_each do |entry|
      entry.tag_list.each { |tag| tag_counts[tag] += 1 }
    end

    tag_counts.sort_by { |tag, count| -count }.first(10).map do |tag, count|
      { tag: tag, count: count }
    end
  end
end
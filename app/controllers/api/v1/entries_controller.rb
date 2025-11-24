class Api::V1::EntriesController < Api::BaseController
  before_action :find_entry, only: [:show, :update, :destroy, :categorize, :add_tags]

  def index
    entries = current_user.entries.active

    # Фильтры
    entries = entries.where(entry_type: params[:type]) if params[:type].present?
    entries = entries.by_category(params[:category]) if params[:category].present?
    entries = entries.where(dashboard_status: params[:status]) if params[:status].present?
    
    # Поиск
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      entries = entries.where("content LIKE ? COLLATE NOCASE OR transcript LIKE ? COLLATE NOCASE", search_term, search_term)
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
  
  def create
    entry = current_user.entries.build(entry_create_params)
    
    if entry.save
      success_response(serialize_entry_full(entry), message: "Entry created successfully", status: :created)
    else
      error_response("Failed to create entry", status: :unprocessable_entity, details: entry.errors.full_messages)
    end
  end

  def update
    if @entry.update(entry_update_params)
      success_response(serialize_entry_full(@entry), message: "Entry updated successfully")
    else
      error_response("Failed to update entry", status: :unprocessable_entity, details: @entry.errors)
    end
  end

  def destroy
    if @entry.update(status: 'deleted')
      success_response(nil, message: "Entry deleted successfully")
    else
      error_response("Failed to delete entry", status: :unprocessable_entity, details: @entry.errors)
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
    
    # Vector similarity search is no longer available with SQLite3
    # Return entries with similar content using text matching instead
    search_terms = @entry.content.split.first(5).map { |word| "%#{word}%" }
    similar_entries = current_user.entries.active
                                  .where.not(id: @entry.id)
                                  .where(
                                    search_terms.map { |term| "content LIKE ? COLLATE NOCASE" }.join(" OR "),
                                    *search_terms
                                  )
                                  .limit(10)

    success_response({
      similar_entries: similar_entries.map { |entry| serialize_entry(entry) },
      note: "Using text-based similarity search (vector search unavailable)"
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

  def upload_audio
    unless params[:audio].present?
      return error_response("Audio file is required", status: :bad_request)
    end
    
    begin
      audio_file = params[:audio]
      
      # Read audio data
      audio_data = audio_file.read
      
      # Transcribe with Whisper
      transcript = Ai::WhisperService.transcribe(audio_data)
      
      unless transcript
        return error_response("Failed to transcribe audio", status: :unprocessable_entity)
      end
      
      # Process content using the same logic as Telegram handler
      analyses = Ai::MultiPlanAnalyzer.analyze(transcript, user: current_user)
      
      created_entries = []
      
      # Check if we should group related ideas
      should_group_ideas = analyses.count > 1 && 
                          analyses.all? { |a| a[:type] == 'idea' }
      
      parent_entry = nil
      group_id = should_group_ideas ? SecureRandom.uuid : nil
      
      analyses.each_with_index do |analysis, index|
        # For grouped ideas, create first as parent, rest as children
        if should_group_ideas && index == 0
          # Create main parent entry with combined content
          combined_content = "#{analysis[:content] || analysis[:summary]}\n\nСвязанные размышления:\n" + 
                            analyses[1..-1].map { |a| "• #{a[:content] || a[:summary]}" }.join("\n")
          
          parent_entry = current_user.entries.create!(
            entry_type: analysis[:type],
            content: combined_content,
            transcript: transcript,
            priority: analysis[:priority] || 0,
            group_id: group_id,
            metadata: {
              multi_plan_source: true,
              plan_index: 1,
              total_plans: analyses.count,
              is_grouped_idea: true,
              grouped_content_count: analyses.count,
              source: 'dashboard_upload'
            }.merge(analysis[:metadata] || {})
          )
          
          created_entries << parent_entry
          
        elsif should_group_ideas && index > 0
          # Create child entries for additional ideas
          child_entry = current_user.entries.create!(
            entry_type: analysis[:type],
            content: analysis[:content] || analysis[:summary] || transcript,
            transcript: transcript,
            priority: analysis[:priority] || 0,
            group_id: group_id,
            parent_entry: parent_entry,
            metadata: {
              multi_plan_source: true,
              plan_index: index + 1,
              total_plans: analyses.count,
              is_grouped_idea_child: true,
              source: 'dashboard_upload'
            }.merge(analysis[:metadata] || {})
          )
          
          created_entries << child_entry
          
        else
          # Create regular standalone entry
          entry = current_user.entries.create!(
            entry_type: analysis[:type],
            content: analysis[:content] || analysis[:summary] || transcript,
            transcript: transcript,
            priority: analysis[:priority] || 0,
            metadata: {
              multi_plan_source: analyses.count > 1,
              plan_index: index + 1,
              total_plans: analyses.count,
              source: 'dashboard_upload'
            }.merge(analysis[:metadata] || {})
          )
          
          created_entries << entry
        end

        # Create calendar event if needed
        if analysis[:create_calendar_event]
          create_calendar_event(created_entries.last, analysis)
        end

        # Create reminder if needed
        if analysis[:create_reminder] && analysis[:reminder_time]
          create_reminder(created_entries.last, analysis)
        end
      end

      success_response({
        entries: created_entries.map { |entry| serialize_entry(entry) },
        transcript: transcript,
        total_created: created_entries.count
      }, message: "Audio processed successfully")

    rescue StandardError => e
      Rails.logger.error "Audio upload error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      error_response("Failed to process audio", status: :internal_server_error)
    end
  end

  private

  def find_entry
    @entry = current_user.entries.find(params[:id])
  end

  def entry_update_params
    params.require(:entry).permit(:content, :entry_type, :category, :dashboard_status, :priority, :tags, :status)
  end
  
  def entry_create_params
    params.permit(:content, :entry_type, :category, :priority)
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

  def create_calendar_event(entry, analysis)
    # Проверяем metadata для all_day события  
    is_all_day = analysis[:metadata]&.dig(:all_day) || analysis[:metadata]&.dig("all_day") || false
    
    # Определяем время события
    if is_all_day && analysis[:event_time].nil?
      # Для all_day событий без времени используем завтрашний день
      start_time = Date.tomorrow.beginning_of_day
      end_time = Date.tomorrow.end_of_day
    else
      start_time = analysis[:event_time]
      end_time = analysis[:event_end_time]
    end
    
    current_user.calendar_events.create!(
      entry: entry,
      title: analysis[:event_title] || entry.content.truncate(100),
      description: entry.content,
      start_time: start_time,
      end_time: end_time,
      event_type: "plan",
      all_day: is_all_day
    )
  rescue StandardError => e
    Rails.logger.error "Error creating calendar event: #{e.message}"
  end

  def create_reminder(entry, analysis)
    current_user.reminders.create!(
      entry: entry,
      reminder_type: "one_time",
      remind_at: analysis[:reminder_time],
      message: analysis[:reminder_message] || entry.content.truncate(200)
    )
  rescue StandardError => e
    Rails.logger.error "Error creating reminder: #{e.message}"
  end
end
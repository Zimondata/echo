class Google::CalendarService
  include ActiveSupport::Benchmarkable

  def initialize(user)
    @user = user
    @oauth_service = Google::OauthService.new(user)
    @calendar_service = nil
  end

  # Get or create authenticated Google Calendar service
  def calendar_client
    return @calendar_service if @calendar_service

    access_token = @oauth_service.get_valid_access_token
    raise GoogleCalendarError, "No valid access token available" unless access_token

    @calendar_service = Google::Apis::CalendarV3::CalendarService.new
    @calendar_service.authorization = build_authorization(access_token)
    @calendar_service.client_options.application_name = Rails.application.config.google_calendar[:application_name]
    @calendar_service
  end

  # Get user's calendars
  def list_calendars
    benchmark "Fetch Google Calendars" do
      response = calendar_client.list_calendar_lists
      
      calendars = response.items.map do |calendar|
        {
          id: calendar.id,
          name: calendar.summary,
          description: calendar.description,
          primary: calendar.primary?,
          access_role: calendar.access_role,
          color: calendar.color_id,
          time_zone: calendar.time_zone
        }
      end
      
      Rails.logger.info "Found #{calendars.count} Google calendars for user #{@user.id}"
      calendars
    end
  rescue Google::Apis::Error => e
    handle_google_api_error(e, "Failed to fetch Google calendars")
  end

  # Get events from Google Calendar
  def fetch_events(calendar_id = 'primary', options = {})
    benchmark "Fetch Google Calendar events" do
      default_options = {
        time_min: 1.week.ago.iso8601,
        time_max: 4.weeks.from_now.iso8601,
        single_events: true,
        order_by: 'startTime'
      }
      
      merged_options = default_options.merge(options)
      
      response = calendar_client.list_events(calendar_id, **merged_options)
      
      events = response.items.map do |event|
        serialize_google_event(event)
      end
      
      Rails.logger.info "Fetched #{events.count} events from Google Calendar"
      events
    end
  rescue Google::Apis::Error => e
    handle_google_api_error(e, "Failed to fetch Google calendar events")
  end

  # Create event in Google Calendar
  def create_event(calendar_event, calendar_id = 'primary')
    benchmark "Create Google Calendar event" do
      google_event = build_google_event(calendar_event)
      
      response = calendar_client.insert_event(calendar_id, google_event)
      
      # Update local event with Google event ID
      calendar_event.update!(google_event_id: response.id)
      
      Rails.logger.info "Created Google Calendar event #{response.id} for local event #{calendar_event.id}"
      serialize_google_event(response)
    end
  rescue Google::Apis::Error => e
    handle_google_api_error(e, "Failed to create Google calendar event")
  end

  # Update event in Google Calendar
  def update_event(calendar_event, calendar_id = 'primary')
    return nil unless calendar_event.google_event_id

    benchmark "Update Google Calendar event" do
      google_event = build_google_event(calendar_event)
      
      response = calendar_client.update_event(
        calendar_id, 
        calendar_event.google_event_id, 
        google_event
      )
      
      Rails.logger.info "Updated Google Calendar event #{response.id}"
      serialize_google_event(response)
    end
  rescue Google::Apis::Error => e
    if e.status_code == 404
      # Event was deleted in Google Calendar, remove reference
      calendar_event.update!(google_event_id: nil)
      Rails.logger.warn "Google Calendar event #{calendar_event.google_event_id} not found, removed reference"
      return nil
    end
    
    handle_google_api_error(e, "Failed to update Google calendar event")
  end

  # Delete event from Google Calendar
  def delete_event(google_event_id, calendar_id = 'primary')
    benchmark "Delete Google Calendar event" do
      calendar_client.delete_event(calendar_id, google_event_id)
      Rails.logger.info "Deleted Google Calendar event #{google_event_id}"
      true
    end
  rescue Google::Apis::Error => e
    if e.status_code == 404
      Rails.logger.warn "Google Calendar event #{google_event_id} not found for deletion"
      return true # Consider it successfully deleted
    end
    
    handle_google_api_error(e, "Failed to delete Google calendar event")
  end

  # Sync local calendar events to Google
  def sync_to_google
    synced_count = 0
    error_count = 0
    
    @user.calendar_events.where(google_event_id: nil).find_each do |event|
      begin
        create_event(event)
        synced_count += 1
      rescue GoogleCalendarError => e
        Rails.logger.error "Failed to sync event #{event.id} to Google: #{e.message}"
        error_count += 1
      end
    end
    
    Rails.logger.info "Synced #{synced_count} events to Google Calendar (#{error_count} errors)"
    { synced: synced_count, errors: error_count }
  end

  # Sync events from Google to local database
  def sync_from_google(calendar_id = 'primary')
    google_events = fetch_events(calendar_id)
    created_count = 0
    updated_count = 0
    
    google_events.each do |google_event|
      local_event = @user.calendar_events.find_by(google_event_id: google_event[:id])
      
      if local_event
        # Update existing event
        if should_update_local_event?(local_event, google_event)
          update_local_event(local_event, google_event)
          updated_count += 1
        end
      else
        # Create new local event
        create_local_event_from_google(google_event)
        created_count += 1
      end
    end
    
    Rails.logger.info "Synced from Google: #{created_count} created, #{updated_count} updated"
    { created: created_count, updated: updated_count }
  end

  # Full bidirectional sync
  def full_sync
    results = {
      to_google: sync_to_google,
      from_google: sync_from_google
    }
    
    # Update user's last sync time
    @user.update!(
      settings: @user.settings.merge({
        last_google_sync: Time.current.iso8601,
        google_sync_results: results
      })
    )
    
    results
  end

  private

  def build_authorization(access_token)
    auth = Signet::OAuth2::Client.new
    auth.access_token = access_token
    auth
  end

  def serialize_google_event(google_event)
    {
      id: google_event.id,
      title: google_event.summary,
      description: google_event.description,
      start_time: parse_google_datetime(google_event.start),
      end_time: parse_google_datetime(google_event.end),
      location: google_event.location,
      created: google_event.created,
      updated: google_event.updated,
      creator: google_event.creator&.email,
      attendees: google_event.attendees&.map { |a| { email: a.email, status: a.response_status } }
    }
  end

  def build_google_event(calendar_event)
    Google::Apis::CalendarV3::Event.new(
      summary: calendar_event.title,
      description: calendar_event.description,
      start: build_google_datetime(calendar_event.start_time),
      end: build_google_datetime(calendar_event.end_time || calendar_event.start_time + 1.hour),
      location: calendar_event.metadata['location']
    )
  end

  def build_google_datetime(datetime)
    Google::Apis::CalendarV3::EventDateTime.new(
      date_time: datetime.iso8601,
      time_zone: @user.timezone
    )
  end

  def parse_google_datetime(google_datetime)
    if google_datetime.date_time
      Time.zone.parse(google_datetime.date_time)
    elsif google_datetime.date
      Date.parse(google_datetime.date).beginning_of_day
    else
      nil
    end
  end

  def should_update_local_event?(local_event, google_event)
    # Check if Google event is newer
    google_updated = Time.zone.parse(google_event[:updated])
    local_updated = local_event.updated_at
    
    google_updated > local_updated
  end

  def update_local_event(local_event, google_event)
    local_event.update!(
      title: google_event[:title],
      description: google_event[:description],
      start_time: google_event[:start_time],
      end_time: google_event[:end_time],
      metadata: local_event.metadata.merge({
        location: google_event[:location],
        google_creator: google_event[:creator],
        google_attendees: google_event[:attendees]
      })
    )
  end

  def create_local_event_from_google(google_event)
    @user.calendar_events.create!(
      google_event_id: google_event[:id],
      title: google_event[:title],
      description: google_event[:description],
      start_time: google_event[:start_time],
      end_time: google_event[:end_time],
      event_type: 'google_import',
      metadata: {
        location: google_event[:location],
        google_creator: google_event[:creator],
        google_attendees: google_event[:attendees],
        imported_at: Time.current.iso8601
      }
    )
  end

  def handle_google_api_error(error, context)
    Rails.logger.error "Google Calendar API Error (#{context}): #{error.message}"
    
    case error.status_code
    when 401
      raise GoogleCalendarError, "Google Calendar authorization expired. Please reconnect."
    when 403
      raise GoogleCalendarError, "Insufficient permissions for Google Calendar access"
    when 404
      raise GoogleCalendarError, "Google Calendar resource not found"
    when 429
      raise GoogleCalendarError, "Google Calendar API rate limit exceeded. Please try again later."
    else
      raise GoogleCalendarError, "Google Calendar API error: #{error.message}"
    end
  end

  def logger
    Rails.logger
  end
end

# Custom error class
class GoogleCalendarError < StandardError; end
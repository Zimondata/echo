class Google::SyncEventJob < ApplicationJob
  queue_as :default

  retry_on GoogleCalendarError, wait: :polynomially_longer, attempts: 2
  retry_on Google::Apis::Error, wait: :polynomially_longer, attempts: 2

  def perform(calendar_event_id, action = 'create')
    @calendar_event = CalendarEvent.find(calendar_event_id)
    @user = @calendar_event.user
    
    unless Google::OauthService.connected?(@user)
      Rails.logger.info "Skipping event sync: Google Calendar not connected for user #{@user.id}"
      return
    end

    @calendar_service = Google::CalendarService.new(@user)
    
    case action
    when 'create'
      sync_create_event
    when 'update'
      sync_update_event
    when 'delete'
      sync_delete_event
    else
      Rails.logger.error "Unknown sync action: #{action}"
    end

  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "Calendar event #{calendar_event_id} not found for sync"
    
  rescue GoogleCalendarError => e
    Rails.logger.error "Google Calendar event sync failed: #{e.message}"
    
    # Mark event as sync failed
    @calendar_event&.update!(
      metadata: (@calendar_event.metadata || {}).merge({
        google_sync_error: e.message,
        google_sync_failed_at: Time.current.iso8601
      })
    )
    
    raise e
    
  rescue StandardError => e
    Rails.logger.error "Unexpected error during event sync: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    raise e
  end

  private

  def sync_create_event
    return if @calendar_event.google_event_id.present?
    
    Rails.logger.info "Creating Google Calendar event for local event #{@calendar_event.id}"
    
    google_event = @calendar_service.create_event(@calendar_event)
    
    if google_event
      Rails.logger.info "Successfully created Google Calendar event #{@calendar_event.google_event_id}"
      
      # Clear any previous sync errors
      @calendar_event.metadata = (@calendar_event.metadata || {}).except('google_sync_error', 'google_sync_failed_at')
      @calendar_event.metadata['google_synced_at'] = Time.current.iso8601
      @calendar_event.save!
    end
  end

  def sync_update_event
    return unless @calendar_event.google_event_id.present?
    
    Rails.logger.info "Updating Google Calendar event #{@calendar_event.google_event_id}"
    
    google_event = @calendar_service.update_event(@calendar_event)
    
    if google_event
      Rails.logger.info "Successfully updated Google Calendar event #{@calendar_event.google_event_id}"
      
      # Update sync metadata
      @calendar_event.metadata = (@calendar_event.metadata || {}).except('google_sync_error', 'google_sync_failed_at')
      @calendar_event.metadata['google_synced_at'] = Time.current.iso8601
      @calendar_event.save!
    elsif @calendar_event.google_event_id.nil?
      # Event was removed from Google Calendar, try to create new one
      Rails.logger.info "Google Calendar event was deleted, creating new one"
      sync_create_event
    end
  end

  def sync_delete_event
    return unless @calendar_event.google_event_id.present?
    
    Rails.logger.info "Deleting Google Calendar event #{@calendar_event.google_event_id}"
    
    if @calendar_service.delete_event(@calendar_event.google_event_id)
      Rails.logger.info "Successfully deleted Google Calendar event #{@calendar_event.google_event_id}"
    end
  end
end
class Google::SyncCalendarJob < ApplicationJob
  queue_as :default

  retry_on GoogleCalendarError, wait: :polynomially_longer, attempts: 3
  retry_on Google::Apis::Error, wait: :polynomially_longer, attempts: 3

  def perform(user_id, sync_direction = 'full')
    @user = User.find(user_id)
    
    unless Google::OauthService.connected?(@user)
      Rails.logger.warn "Skipping calendar sync for user #{user_id}: Google Calendar not connected"
      return
    end

    @calendar_service = Google::CalendarService.new(@user)
    
    case sync_direction
    when 'to_google'
      sync_to_google
    when 'from_google'
      sync_from_google
    when 'full'
      full_sync
    else
      Rails.logger.error "Unknown sync direction: #{sync_direction}"
      return
    end

  rescue GoogleCalendarError => e
    Rails.logger.error "Google Calendar sync failed for user #{user_id}: #{e.message}"
    
    # Notify user about sync failure
    create_sync_notification('error', e.message)
    
    raise e # Re-raise to trigger retry logic
    
  rescue StandardError => e
    Rails.logger.error "Unexpected error during calendar sync for user #{user_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    create_sync_notification('error', 'Calendar sync failed due to unexpected error')
    
    raise e
  end

  private

  def sync_to_google
    Rails.logger.info "Starting sync TO Google Calendar for user #{@user.id}"
    
    results = @calendar_service.sync_to_google
    
    message = "Synced #{results[:synced]} events to Google Calendar"
    message += " (#{results[:errors]} errors)" if results[:errors] > 0
    
    create_sync_notification('success', message)
    Rails.logger.info "Completed sync TO Google Calendar for user #{@user.id}: #{results}"
  end

  def sync_from_google
    Rails.logger.info "Starting sync FROM Google Calendar for user #{@user.id}"
    
    results = @calendar_service.sync_from_google
    
    message = "Imported #{results[:created]} new events, updated #{results[:updated]} events from Google Calendar"
    
    create_sync_notification('success', message)
    Rails.logger.info "Completed sync FROM Google Calendar for user #{@user.id}: #{results}"
  end

  def full_sync
    Rails.logger.info "Starting FULL sync with Google Calendar for user #{@user.id}"
    
    results = @calendar_service.full_sync
    
    to_google = results[:to_google]
    from_google = results[:from_google]
    
    message_parts = []
    message_parts << "Synced #{to_google[:synced]} events to Google" if to_google[:synced] > 0
    message_parts << "Imported #{from_google[:created]} new events" if from_google[:created] > 0
    message_parts << "Updated #{from_google[:updated]} events" if from_google[:updated] > 0
    
    message = message_parts.any? ? message_parts.join(", ") : "Calendar is up to date"
    
    create_sync_notification('success', "Calendar sync completed: #{message}")
    Rails.logger.info "Completed FULL sync with Google Calendar for user #{@user.id}: #{results}"
    
    # Schedule next automatic sync
    schedule_next_sync
  end

  def create_sync_notification(type, message)
    # In a real app, this would create a user notification
    # For now, we'll just log it and store in user settings
    
    notification = {
      type: type,
      message: message,
      timestamp: Time.current.iso8601
    }
    
    current_notifications = @user.settings.dig('sync_notifications') || []
    current_notifications.unshift(notification)
    current_notifications = current_notifications.first(10) # Keep only last 10 notifications
    
    @user.update!(
      settings: @user.settings.merge({
        sync_notifications: current_notifications
      })
    )
    
    Rails.logger.info "Calendar sync notification for user #{@user.id}: #{message}"
  end

  def schedule_next_sync
    # Schedule next automatic sync in 4 hours
    Google::SyncCalendarJob.set(wait: 4.hours).perform_later(@user.id, 'full')
  end
end
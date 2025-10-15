class DeleteGoogleEventJob < ApplicationJob
  queue_as :default

  retry_on GoogleCalendarError, wait: :polynomially_longer, attempts: 2
  retry_on Google::Apis::Error, wait: :polynomially_longer, attempts: 2

  def perform(google_event_id, user_id)
    user = User.find(user_id)
    
    unless Google::OauthService.connected?(user)
      Rails.logger.info "Skipping Google event deletion: not connected for user #{user_id}"
      return
    end

    calendar_service = Google::CalendarService.new(user)
    
    if calendar_service.delete_event(google_event_id)
      Rails.logger.info "Successfully deleted Google Calendar event #{google_event_id}"
    end

  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "User #{user_id} not found for Google event deletion"
    
  rescue GoogleCalendarError => e
    Rails.logger.error "Failed to delete Google Calendar event #{google_event_id}: #{e.message}"
    # Don't re-raise - event deletion is not critical
    
  rescue StandardError => e
    Rails.logger.error "Unexpected error during Google event deletion: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Don't re-raise - event deletion is not critical
  end
end
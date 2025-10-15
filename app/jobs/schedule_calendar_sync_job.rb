class ScheduleCalendarSyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting scheduled calendar sync for all connected users"
    
    sync_count = 0
    error_count = 0
    
    # Find all users with Google Calendar connected
    User.with_google_connected.find_each do |user|
      begin
        # Only sync if last sync was more than 2 hours ago
        last_sync = user.settings.dig('last_google_sync')
        
        if last_sync.nil? || Time.zone.parse(last_sync) < 2.hours.ago
          Google::SyncCalendarJob.perform_later(user.id, 'full')
          sync_count += 1
        else
          Rails.logger.debug "Skipping sync for user #{user.id}: recent sync exists"
        end
        
      rescue StandardError => e
        Rails.logger.error "Error scheduling sync for user #{user.id}: #{e.message}"
        error_count += 1
      end
    end
    
    Rails.logger.info "Scheduled calendar sync for #{sync_count} users (#{error_count} errors)"
  end
end
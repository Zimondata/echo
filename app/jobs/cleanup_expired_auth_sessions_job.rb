class CleanupExpiredAuthSessionsJob < ApplicationJob
  queue_as :default

  def perform
    expired_count = TelegramAuthSession.expired.update_all(status: 'expired')
    Rails.logger.info "Expired #{expired_count} auth sessions"
  end
end

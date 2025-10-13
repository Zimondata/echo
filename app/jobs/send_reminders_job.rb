class SendRemindersJob < ApplicationJob
  queue_as :default

  def perform
    # Find all reminders that are due
    Reminder.due.find_each do |reminder|
      send_reminder(reminder)
    end
  end

  private

  def send_reminder(reminder)
    user = reminder.user
    message = reminder.message || "Напоминание"

    # Add entry info if available
    if reminder.entry
      entry = reminder.entry
      message = "🔔 *Напоминание*\n\n#{message}\n\n📝 Связанная запись:\n#{entry.content.truncate(100)}"
    else
      message = "🔔 *Напоминание*\n\n#{message}"
    end

    # Send to Telegram
    success = Telegram::BotService.send_message(
      chat_id: user.telegram_id,
      text: message
    )

    # Mark as sent
    reminder.mark_as_sent! if success

  rescue StandardError => e
    Rails.logger.error "Failed to send reminder #{reminder.id}: #{e.message}"
  end
end

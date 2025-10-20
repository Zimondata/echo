class SendRemindersJob < ApplicationJob
  queue_as :default

  # Note: limits_concurrency was removed (Solid Queue specific, using async adapter)

  def perform
    # Find all reminders that are due
    Reminder.due.find_each do |reminder|
      send_reminder(reminder)
    end
  end

  private

  def send_reminder(reminder)
    # Skip if already sent (double check for race conditions)
    return if reminder.status == "sent"
    
    # Reload to get latest status and check again
    reminder.reload
    return if reminder.status == "sent"
    
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

    # Mark as sent and handle recurring reminders
    if success
      reminder.mark_as_sent!
      schedule_next_recurring_reminder(reminder) if reminder.reminder_type == "recurring"
    end

  rescue StandardError => e
    Rails.logger.error "Failed to send reminder #{reminder.id}: #{e.message}"
  end

  def schedule_next_recurring_reminder(original_reminder)
    # Get recurring settings from metadata
    metadata = original_reminder.metadata || {}
    interval_hours = metadata["interval_hours"] || 3
    end_time = metadata["end_time"] # Format: "22:00"
    
    # Calculate next reminder time
    next_time = original_reminder.remind_at + interval_hours.hours
    
    # Check if next time is before end_time today, or start tomorrow
    if end_time
      today_end = Time.zone.parse(end_time)
      today_end = today_end.tomorrow if today_end <= Time.current
      
      # If next_time is after end_time today, start tomorrow at first interval
      if next_time > today_end
        tomorrow_start = Time.zone.tomorrow.beginning_of_day + 9.hours # Start at 9 AM
        next_time = tomorrow_start
      end
    end
    
    # Create next recurring reminder
    Reminder.create!(
      user: original_reminder.user,
      entry: original_reminder.entry,
      reminder_type: "recurring",
      remind_at: next_time,
      message: original_reminder.message,
      status: "pending",
      metadata: original_reminder.metadata
    )
    
    Rails.logger.info "Scheduled next recurring reminder for #{original_reminder.user.telegram_id} at #{next_time}"
  end
end

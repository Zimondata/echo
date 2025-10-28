class GenerateSmartRemindersJob < ApplicationJob
  queue_as :default

  # This job runs periodically (e.g., every 6 hours) to generate smart reminders for active users
  def perform
    Rails.logger.info "Starting smart reminders generation..."

    active_users = User.active.where("last_entry_timestamp > ?", 7.days.ago)

    active_users.find_each do |user|
      generate_reminders_for_user(user)
    end

    Rails.logger.info "Finished smart reminders generation for #{active_users.count} users"
  end

  private

  def generate_reminders_for_user(user)
    # Check if user has recent smart reminders
    recent_smart_reminders = user.reminders
      .smart
      .where("created_at > ?", 6.hours.ago)
      .count

    # Don't spam with too many smart reminders
    return if recent_smart_reminders >= 3

    # Check user preferences (if they have smart reminders enabled)
    # For now, assume all users want them
    # Later: add user setting: smart_reminders_enabled

    # Generate smart reminders using the engine
    engine = Ai::SmartReminderEngine.new(user)
    suggestions = engine.generate_reminders

    # Limit to top 3 suggestions
    top_suggestions = suggestions.first(3)

    top_suggestions.each do |suggestion|
      create_smart_reminder(user, suggestion)
    end

    Rails.logger.info "Generated #{top_suggestions.count} smart reminders for user #{user.id}"

  rescue StandardError => e
    Rails.logger.error "Error generating smart reminders for user #{user.id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  def create_smart_reminder(user, suggestion)
    # Check if similar reminder already exists
    existing = user.reminders
      .pending
      .where("message LIKE ?", "#{suggestion[:message][0..50]}%")
      .exists?

    return if existing

    reminder = user.reminders.create!(
      reminder_type: "smart",
      smart_type: suggestion[:smart_type],
      smart_trigger: suggestion[:smart_trigger],
      message: suggestion[:message],
      priority: suggestion[:priority],
      confidence_score: suggestion[:confidence],
      related_entry_ids: suggestion[:related_entry_ids],
      ai_context: suggestion[:ai_context],
      action_buttons: suggestion[:action_buttons],
      remind_at: suggestion[:remind_at],
      status: "pending"
    )

    Rails.logger.info "Created smart reminder #{reminder.id} (#{suggestion[:smart_type]}) for user #{user.id}"
  end
end

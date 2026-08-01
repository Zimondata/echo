class SendRemindersJob < ApplicationJob
  queue_as :default

  # Note: limits_concurrency was removed (Solid Queue specific, using async adapter)

  def perform
    # Recover claims left behind by a crashed worker. Normal Telegram delivery
    # should complete far sooner than this lease.
    Reminder.where(status: "sending").where("updated_at < ?", 15.minutes.ago)
      .update_all(status: "pending", updated_at: Time.current)

    # Find all reminders that are due
    Reminder.due.find_each do |reminder|
      send_reminder(reminder)
    end
  end

  private

  def send_reminder(reminder)
    # Atomic claim prevents two workers from delivering the same row.
    claimed = Reminder.where(id: reminder.id, status: "pending")
      .update_all(status: "sending", updated_at: Time.current)
    return unless claimed == 1

    reminder.reload
    user = reminder.user
    return if postpone_for_quiet_hours?(reminder, user)

    # Validate recurrence before the Telegram side effect. Invalid legacy
    # metadata must not send once and then release the row for a duplicate.
    recurring_attributes = next_recurring_reminder_attributes(reminder) if reminder.reminder_type == "recurring"

    delivered = if reminder.smart_reminder?
      send_smart_reminder(reminder, user)
    else
      send_regular_reminder(reminder, user)
    end
    return release_delivery_claim(reminder) unless delivered

    Reminder.transaction do
      reminder.lock!
      return unless reminder.status == "sending"

      reminder.mark_as_sent!
      Reminder.create!(recurring_attributes) if recurring_attributes
    end
  rescue StandardError => e
    release_delivery_claim(reminder)
    Rails.logger.error "Failed to send reminder #{reminder.id}: #{e.message}"
  end

  def postpone_for_quiet_hours?(reminder, user)
    return false if %w[high critical].include?(reminder.priority)

    settings = user.settings || {}
    quiet_start = settings["quiet_start"]
    quiet_end = settings["quiet_end"]
    return false if quiet_start.blank? || quiet_end.blank?

    zone = ActiveSupport::TimeZone[user.timezone] || Time.zone
    now = Time.current.in_time_zone(zone)
    start_hour, start_minute = parse_clock(quiet_start)
    end_hour, end_minute = parse_clock(quiet_end)
    start_at = local_wall_time(zone, now.to_date, start_hour, start_minute)
    end_at = local_wall_time(zone, now.to_date, end_hour, end_minute)

    if start_at <= end_at
      return false unless now.between?(start_at, end_at)
    elsif now >= start_at
      end_at += 1.day
    elsif now >= end_at
      return false
    end

    reminder.update!(status: "pending", remind_at: end_at)
    Rails.logger.info "Reminder #{reminder.id} postponed until quiet hours end at #{end_at}"
    true
  rescue ArgumentError, TypeError => e
    reminder.update!(status: "pending", remind_at: 1.hour.from_now)
    Rails.logger.error "Reminder #{reminder.id} held because quiet-hours configuration is invalid: #{e.message}"
    true
  end

  def send_regular_reminder(reminder, user)
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

    success == true
  end

  def send_smart_reminder(reminder, user)
    message = reminder.formatted_message

    # Add related entries context if available
    if reminder.related_entries.any?
      related_content = reminder.related_entries.first.content.truncate(80)
      message += "\n\n💭 Связано с: \"#{related_content}\""
    end

    # Add confidence if low (so user knows it's a suggestion)
    if reminder.confidence_score && reminder.confidence_score < 75
      message += "\n\n_Это предложение на основе анализа твоих записей_"
    end

    # Prepare inline keyboard if action buttons exist
    keyboard = nil
    if reminder.action_buttons.present? && reminder.action_buttons.is_a?(Array)
      keyboard = build_inline_keyboard(reminder.action_buttons, reminder.id)
    end

    # Send to Telegram
    success = Telegram::BotService.send_message(
      chat_id: user.telegram_id,
      text: message,
      reply_markup: keyboard
    )

    success == true
  end

  def release_delivery_claim(reminder)
    Reminder.where(id: reminder.id, status: "sending")
      .update_all(status: "pending", updated_at: Time.current)
  end

  def build_inline_keyboard(buttons, reminder_id)
    # Telegram inline keyboard format
    inline_keyboard = buttons.map do |btn|
      {
        text: btn["text"] || btn[:text],
        callback_data: "reminder_#{reminder_id}_#{btn['callback'] || btn[:callback]}"
      }
    end

    # Add default snooze and dismiss buttons
    inline_keyboard << { text: "⏰ Напомнить позже", callback_data: "reminder_#{reminder_id}_snooze" }
    inline_keyboard << { text: "✅ Понятно", callback_data: "reminder_#{reminder_id}_dismiss" }

    # Group buttons in rows (2 per row)
    rows = inline_keyboard.each_slice(2).to_a

    { inline_keyboard: rows }
  end

  def next_recurring_reminder_attributes(original_reminder)
    metadata = original_reminder.metadata || {}
    interval_hours = Integer(metadata["interval_hours"] || 3)
    zone = ActiveSupport::TimeZone[original_reminder.user.timezone] || Time.zone
    current_local = original_reminder.remind_at.in_time_zone(zone)
    next_time = advance_local_wall_clock(current_local, interval_hours, zone)

    start_hour, start_minute = parse_clock(metadata["start_time"] || "09:00")
    if metadata["end_time"].present?
      end_hour, end_minute = parse_clock(metadata["end_time"])
      end_today = local_wall_time(zone, current_local.to_date, end_hour, end_minute)
      next_local = next_time.in_time_zone(zone)

      if next_local.to_date == current_local.to_date && next_time > end_today
        next_time = local_wall_time(zone, current_local.to_date + 1.day, start_hour, start_minute)
      elsif next_local.to_date > current_local.to_date &&
          (next_local.hour * 60 + next_local.min) < (start_hour * 60 + start_minute)
        next_time = local_wall_time(zone, next_local.to_date, start_hour, start_minute)
      end
    end

    {
      user: original_reminder.user,
      entry: original_reminder.entry,
      reminder_type: "recurring",
      remind_at: next_time,
      message: original_reminder.message,
      status: "pending",
      priority: original_reminder.priority,
      recurrence_rule: original_reminder.recurrence_rule,
      metadata: original_reminder.metadata
    }
  end

  def advance_local_wall_clock(local_time, interval_hours, zone)
    naive = DateTime.new(
      local_time.year,
      local_time.month,
      local_time.day,
      local_time.hour,
      local_time.min,
      local_time.sec,
      0
    ) + Rational(interval_hours, 24)

    local_wall_time(zone, naive.to_date, naive.hour, naive.min, naive.sec)
  end

  def local_wall_time(zone, date, hour, minute, second = 0)
    candidate = Time.utc(date.year, date.month, date.day, hour, minute, second)

    # Spring-forward gaps have no valid local instant. Move to the first valid
    # local minute rather than silently preserving an unexpected UTC offset.
    while zone.tzinfo.periods_for_local(candidate).empty?
      candidate += 1.minute
    end

    zone.local(candidate.year, candidate.month, candidate.day, candidate.hour, candidate.min, candidate.sec)
  end

  def parse_clock(value)
    match = value.to_s.match(/\A([01]\d|2[0-3]):([0-5]\d)\z/)
    raise ArgumentError, "Invalid recurring reminder clock" unless match

    [ match[1].to_i, match[2].to_i ]
  end
end

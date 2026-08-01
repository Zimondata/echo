class DailyMorningSummaryJob < ApplicationJob
  queue_as :default

  def perform
    # Отправляем утреннюю сводку всем активным пользователям
    User.active.find_each do |user|
      send_morning_summary_to_user(user)
    end
  end

  private

  def send_morning_summary_to_user(user)
    # Получаем текущий день в timezone пользователя
    user_timezone = ActiveSupport::TimeZone[user.timezone] || Time.zone
    current_day = Time.current.in_time_zone(user_timezone).to_date
    
    # Получаем события на сегодня
    day_start = user_timezone.local(current_day.year, current_day.month, current_day.day).beginning_of_day
    day_end = day_start.end_of_day
    
    today_events = user.calendar_events
                      .active
                      .where(start_time: day_start..day_end)
                      .order(:start_time)
    
    # Получаем напоминания на сегодня
    today_reminders = user.reminders
                         .pending
                         .where(remind_at: day_start..day_end)
                         .order(:remind_at)
    
    # Формируем сообщение
    message = build_morning_message(user, current_day, today_events, today_reminders)
    
    # Отправляем сообщение
    delivered = Telegram::BotService.send_message(
      chat_id: user.telegram_id,
      text: message,
      parse_mode: 'Markdown'
    )
    raise "Telegram rejected morning summary" unless delivered == true

    Rails.logger.info "Morning summary sent to user #{user.id} (#{user.full_name})"
  rescue StandardError => e
    Rails.logger.error "Failed to send morning summary to user #{user.id}: #{e.message}"
  end

  def build_morning_message(user, current_day, events, reminders)
    message = "🌅 *Доброе утро, #{user.full_name}!*\n\n"
    message += "📅 *#{current_day.strftime('%A, %d %B %Y')}*\n\n"
    
    # Статистика дня
    total_items = events.count + reminders.count
    
    if total_items == 0
      message += "🎉 У вас свободный день! Время для отдыха или спонтанных дел.\n\n"
      message += "💡 Может быть, стоит:\n"
      message += "• Поработать над личными проектами\n"
      message += "• Почитать что-то интересное\n"
      message += "• Встретиться с друзьями\n"
      message += "• Заняться хобби\n\n"
    else
      message += "📋 *Планы на сегодня:*\n\n"
      
      # События с временем
      timed_events = events.reject(&:all_day?)
      if timed_events.any?
        timed_events.each do |event|
          time_str = event.start_time.in_time_zone(user.timezone).strftime('%H:%M')
          status_icon = event.done? ? "✅" : "⏰"
          message += "#{status_icon} #{time_str} - #{event.title}\n"
        end
        message += "\n"
      end
      
      # Планы без времени
      floating_events = events.select(&:all_day?)
      if floating_events.any?
        floating_events.each do |event|
          status_icon = event.done? ? "✅" : "📋"
          message += "#{status_icon} #{event.title}\n"
        end
        message += "\n"
      end
      
      # Напоминания
      if reminders.any?
        reminders.each do |reminder|
          time_str = reminder.remind_at.in_time_zone(user.timezone).strftime('%H:%M')
          message += "🔔 #{time_str} - #{reminder.message}\n"
        end
        message += "\n"
      end
    end
    
    message += get_simple_motivation(total_items)
    message
  end

  def pluralize_items(count)
    case count
    when 1
      "дело"
    when 2..4
      "дела"
    else
      "дел"
    end
  end

  def get_simple_motivation(total_items)
    motivational_messages = [
      "✨ Желаю хорошего дня! Пусть всё получится легко и приятно.",
      "🌟 Пусть этот день принесёт много радости и маленьких побед!",
      "💫 Желаю вдохновения и энергии на весь день!",
      "🌈 Пусть день пройдёт гладко и оставит приятные воспоминания.",
      "⭐ Желаю, чтобы все планы осуществились без стресса!",
      "🎯 Пусть сегодня всё складывается именно так, как нужно.",
      "🌸 Желаю лёгкости в делах и хорошего настроения!"
    ]
    
    motivational_messages.sample + "\n"
  end
end
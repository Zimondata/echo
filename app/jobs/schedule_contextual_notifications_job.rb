class ScheduleContextualNotificationsJob < ApplicationJob
  queue_as :default

  # Этот джоб запускается каждый час для планирования уведомлений
  def perform
    Rails.logger.info "Scheduling contextual notifications..."

    User.joins(:entries)
        .where(entries: { created_at: 30.days.ago..Time.current })
        .distinct
        .find_each do |user|
      
      schedule_user_notifications(user)
    end
  rescue StandardError => e
    Rails.logger.error "Error scheduling contextual notifications: #{e.message}"
  end

  private

  def schedule_user_notifications(user)
    context = Ai::ContextAnalyzer.analyze_context(user: user)
    current_hour = Time.current.hour
    
    # Утреннее планирование (7-10)
    if should_schedule_morning_planning?(user, context, current_hour)
      schedule_notification(user, 'morning_planning')
    end
    
    # Оптимизация энергии (в часы высокой энергии)
    if should_schedule_energy_optimization?(user, context, current_hour)
      schedule_notification(user, 'energy_optimization')
    end
    
    # Проверка продуктивности (в середине дня)
    if should_schedule_productivity_check?(user, context, current_hour)
      schedule_notification(user, 'productivity_check')
    end
    
    # Вечерняя рефлексия (18-21)
    if should_schedule_daily_reflection?(user, context, current_hour)
      schedule_notification(user, 'daily_reflection')
    end
    
    # Контекстуальные предложения (в любое время при высоком приоритете)
    if should_schedule_context_suggestions?(user, context)
      schedule_notification(user, 'context_suggestions')
    end
    
    # Конфликты расписания (если обнаружены)
    schedule_conflicts = detect_schedule_conflicts(user)
    if schedule_conflicts.any?
      schedule_notification(user, 'schedule_conflicts', { conflicts: schedule_conflicts })
    end
    
  rescue StandardError => e
    Rails.logger.error "Error scheduling notifications for user #{user.id}: #{e.message}"
  end

  def should_schedule_morning_planning?(user, context, hour)
    return false unless hour.between?(7, 10) # Только утром
    return false if notification_sent_today?(user, 'morning_planning')
    
    # Проверяем активность и наличие задач для планирования
    has_tasks = user.entries.where(dashboard_status: ['new', 'triaged']).exists?
    behavioral = context[:behavioral_context]
    inactive_too_long = behavioral[:hours_since_last_activity] > 12
    
    has_tasks || inactive_too_long
  end

  def should_schedule_energy_optimization?(user, context, hour)
    return false if recent_notification_sent?(user, 'energy_optimization', 2.hours)
    
    temporal = context[:temporal_context]
    energy_level = temporal[:energy_level]
    
    # Только при высокой энергии
    return false unless energy_level == 'high'
    
    # И при низкой текущей активности
    today_activity = context[:productivity_context][:today_activity][:total_entries]
    today_activity < 3
  end

  def should_schedule_productivity_check?(user, context, hour)
    return false unless hour.between?(13, 16) # Только в середине дня
    return false if notification_sent_today?(user, 'productivity_check')
    
    # Только при низкой продуктивности
    productivity = context[:productivity_context][:today_activity][:productivity_score]
    productivity < 40
  end

  def should_schedule_daily_reflection?(user, context, hour)
    return false unless hour.between?(18, 21) # Только вечером
    return false if notification_sent_today?(user, 'daily_reflection')
    
    # Проверяем, есть ли активность за день
    today_entries = context[:productivity_context][:today_activity][:total_entries]
    return false if today_entries < 2 # Мало активности
    
    # Проверяем, нет ли уже рефлексии
    has_reflection = user.entries.diaries
                        .where(created_at: Time.current.beginning_of_day..Time.current)
                        .exists?
    
    !has_reflection
  end

  def should_schedule_context_suggestions?(user, context)
    return false if recent_notification_sent?(user, 'context_suggestions', 4.hours)
    
    # Только при высокоприоритетных предложениях
    high_priority_suggestions = context[:suggestions].count { |s| s[:priority] == 'high' }
    high_priority_suggestions > 0
  end

  def detect_schedule_conflicts(user)
    conflicts = []
    
    # Получаем события на сегодня и завтра
    events = user.calendar_events
                .where(start_time: Time.current..2.days.from_now)
                .order(:start_time)
    
    # Проверяем пересечения
    events.each_with_index do |event, index|
      next_event = events[index + 1]
      next unless next_event
      
      # Если события пересекаются
      if event.end_time > next_event.start_time
        conflicts << {
          time: event.start_time.in_time_zone(user.timezone).strftime('%d.%m в %H:%M'),
          description: "#{event.title} пересекается с #{next_event.title}"
        }
      end
    end
    
    # Проверяем перегруженность дня (>8 часов событий)
    daily_workload = events.group_by { |e| e.start_time.to_date }
                          .transform_values do |day_events|
                            day_events.sum { |e| (e.end_time - e.start_time) / 1.hour }
                          end
    
    daily_workload.each do |date, hours|
      if hours > 8
        conflicts << {
          time: date.strftime('%d.%m'),
          description: "Перегруженный день - #{hours.round(1)} часов событий"
        }
      end
    end
    
    conflicts
  end

  def schedule_notification(user, type, options = {})
    # Немедленная отправка для критических уведомлений
    if critical_notification?(type)
      ContextualNotificationJob.perform_now(user.id, type, options)
    else
      # Отложенная отправка через несколько минут для сглаживания
      delay = rand(1..10).minutes
      ContextualNotificationJob.perform_in(delay, user.id, type, options)
    end
    
    Rails.logger.info "Scheduled #{type} notification for user #{user.id}"
  end

  def critical_notification?(type)
    %w[schedule_conflicts].include?(type)
  end

  def notification_sent_today?(user, type)
    Rails.cache.exist?("notification_#{user.id}_#{type}_#{Date.current}")
  end

  def recent_notification_sent?(user, type, duration)
    last_sent = Rails.cache.read("notification_#{user.id}_#{type}_recent")
    return false unless last_sent
    
    Time.current - last_sent < duration
  end
end
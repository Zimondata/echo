class ContextualNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, notification_type = 'general', options = {})
    @user = User.find(user_id)
    @notification_type = notification_type
    @options = options

    # Анализируем контекст пользователя
    context = Ai::ContextAnalyzer.analyze_context(user: @user)
    
    # Генерируем и отправляем уведомления
    case @notification_type
    when 'morning_planning'
      send_morning_planning_notification(context)
    when 'energy_optimization' 
      send_energy_optimization_notification(context)
    when 'schedule_conflicts'
      send_schedule_conflict_notification(context)
    when 'productivity_check'
      send_productivity_check_notification(context)
    when 'daily_reflection'
      send_daily_reflection_notification(context)
    when 'context_suggestions'
      send_context_suggestions_notification(context)
    else
      send_general_notification(context)
    end
  rescue StandardError => e
    Rails.logger.error "Contextual Notification Job error: #{e.message}"
  end

  private

  def send_morning_planning_notification(context)
    # Отправляем только в утренние часы
    return unless morning_time?
    
    # Проверяем, не отправляли ли уже сегодня
    return if notification_sent_today?('morning_planning')
    
    # Анализируем готовность к планированию
    if should_send_morning_planning?(context)
      suggestions = generate_morning_suggestions(context)
      
      message = build_morning_planning_message(suggestions)
      send_notification(message)
      record_notification('morning_planning')
    end
  end

  def send_energy_optimization_notification(context)
    energy_level = context[:temporal_context][:energy_level]
    
    # Отправляем уведомления только при высоком уровне энергии
    return unless energy_level == 'high'
    
    # Проверяем, что пользователь не очень активен
    today_activity = context[:productivity_context][:today_activity]
    return if today_activity[:total_entries] > 5 # Уже активен
    
    # Проверяем, не отправляли ли недавно (в течение 2 часов)
    return if recent_notification_sent?('energy_optimization', 2.hours)
    
    optimization_suggestions = context[:suggestions].select { |s| s[:type] == 'productivity_boost' }
    
    if optimization_suggestions.any?
      message = build_energy_optimization_message(energy_level, optimization_suggestions)
      send_notification(message)
      record_notification('energy_optimization')
    end
  end

  def send_schedule_conflict_notification(context)
    return unless @options[:conflicts]&.any?
    
    conflicts = @options[:conflicts]
    message = build_schedule_conflict_message(conflicts)
    
    send_notification(message)
    record_notification('schedule_conflicts')
  end

  def send_productivity_check_notification(context)
    # Отправляем в середине дня, если низкая продуктивность
    return unless afternoon_time?
    
    productivity = context[:productivity_context][:today_activity][:productivity_score]
    return unless productivity < 40 # Только при низкой продуктивности
    
    # Не чаще одного раза в день
    return if notification_sent_today?('productivity_check')
    
    message = build_productivity_check_message(productivity, context)
    send_notification(message)
    record_notification('productivity_check')
  end

  def send_daily_reflection_notification(context)
    # Отправляем только вечером
    return unless evening_time?
    
    # Проверяем, есть ли что отрефлексировать
    today_entries = context[:productivity_context][:today_activity][:total_entries]
    return if today_entries < 2 # Мало активности для рефлексии
    
    # Проверяем, не отправляли ли уже
    return if notification_sent_today?('daily_reflection')
    
    # Проверяем, есть ли уже дневниковые записи за сегодня
    has_reflection = @user.entries.diaries
                         .where(created_at: Time.current.beginning_of_day..Time.current)
                         .exists?
                         
    return if has_reflection # Уже есть рефлексия
    
    message = build_daily_reflection_message(today_entries, context)
    send_notification(message)
    record_notification('daily_reflection')
  end

  def send_context_suggestions_notification(context)
    # Отправляем контекстуальные предложения
    relevant_suggestions = context[:suggestions].select { |s| s[:priority] == 'high' }
    
    return if relevant_suggestions.empty?
    
    # Не чаще одного раза в 4 часа
    return if recent_notification_sent?('context_suggestions', 4.hours)
    
    message = build_context_suggestions_message(relevant_suggestions, context)
    send_notification(message)
    record_notification('context_suggestions')
  end

  def send_general_notification(context)
    # Общие уведомления на основе контекста
    optimal_actions = context[:optimal_actions].first(2)
    
    return if optimal_actions.empty?
    
    message = build_general_notification_message(optimal_actions, context)
    send_notification(message)
  end

  # Message builders
  def build_morning_planning_message(suggestions)
    current_time = Time.current.in_time_zone(@user.timezone).strftime('%H:%M')
    
    message = "🌅 *Доброе утро!* (#{current_time})\n\n"
    message += "Время планировать продуктивный день!\n\n"
    
    if suggestions[:pending_tasks] > 0
      message += "📋 У тебя #{suggestions[:pending_tasks]} незавершенных задач\n"
    end
    
    if suggestions[:new_ideas] > 0
      message += "💡 #{suggestions[:new_ideas]} идей ждут воплощения\n"
    end
    
    message += "\n🎯 *Рекомендации:*\n"
    
    suggestions[:recommendations].each do |rec|
      message += "• #{rec}\n"
    end
    
    message += "\nИспользуй /plan для создания расписания или /autoplan для автоматического планирования!"
    
    message
  end

  def build_energy_optimization_message(energy_level, suggestions)
    energy_emoji = energy_level == 'high' ? '⚡' : '🔋'
    
    message = "#{energy_emoji} *Высокий уровень энергии!*\n\n"
    message += "Сейчас #{Time.current.in_time_zone(@user.timezone).strftime('%H:%M')} - отличное время для важных задач!\n\n"
    
    suggestions.each do |suggestion|
      message += "💡 #{suggestion[:message]}\n"
    end
    
    message += "\n🚀 Попробуй команды:\n"
    message += "• /suggest - для умных предложений\n"
    message += "• /plan - для создания плана\n"
    message += "• /optimize - для оптимизации расписания"
    
    message
  end

  def build_schedule_conflict_message(conflicts)
    message = "⚠️ *Конфликт в расписании*\n\n"
    message += "Обнаружены пересечения в твоем календаре:\n\n"
    
    conflicts.each do |conflict|
      message += "🔥 #{conflict[:time]} - #{conflict[:description]}\n"
    end
    
    message += "\n💡 Рекомендуется пересмотреть расписание.\n"
    message += "Используй /calendar для просмотра или /optimize для перепланирования."
    
    message
  end

  def build_productivity_check_message(productivity, context)
    time = Time.current.in_time_zone(@user.timezone).strftime('%H:%M')
    
    message = "📊 *Проверка продуктивности* (#{time})\n\n"
    message += "Сегодня твоя активность ниже обычного (#{productivity}%).\n\n"
    
    behavioral = context[:behavioral_context]
    if behavioral[:hours_since_last_activity] > 3
      message += "🕐 Последняя активность: #{behavioral[:hours_since_last_activity].round} ч. назад\n\n"
    end
    
    message += "💡 *Предложения для повышения продуктивности:*\n"
    message += "• Выбери 1 простую задачу и выполни её\n"
    message += "• Сделай 15-минутную планирующую сессию\n"
    message += "• Попробуй метод помодоро (25 мин работы)\n\n"
    
    message += "Команды: /suggest /plan /autoplan"
    
    message
  end

  def build_daily_reflection_message(entries_count, context)
    message = "🌅 *Время подведения итогов*\n\n"
    message += "Сегодня у тебя было #{entries_count} записей. "
    message += "Отличное время для рефлексии!\n\n"
    
    message += "🤔 *Подумай о:*\n"
    message += "• Что удалось сегодня?\n"
    message += "• Какие были сложности?\n"
    message += "• Что можно улучшить завтра?\n\n"
    
    productivity = context[:productivity_context][:today_activity][:productivity_score]
    if productivity > 70
      message += "🎉 Кстати, сегодня твоя продуктивность #{productivity}% - отлично!\n\n"
    elsif productivity < 40
      message += "💪 Продуктивность сегодня #{productivity}%. Завтра будет лучше!\n\n"
    end
    
    message += "Просто напиши или наговори свои мысли о дне."
    
    message
  end

  def build_context_suggestions_message(suggestions, context)
    temporal = context[:temporal_context]
    time_category = temporal[:time_category] == 'morning' ? 'утром' : 
                   temporal[:time_category] == 'afternoon' ? 'днем' :
                   temporal[:time_category] == 'evening' ? 'вечером' : 'сейчас'
    
    message = "💡 *Умные предложения* #{time_category}\n\n"
    message += "На основе твоих паттернов и текущего контекста:\n\n"
    
    suggestions.each do |suggestion|
      priority_emoji = suggestion[:priority] == 'high' ? '🔥' : '📝'
      message += "#{priority_emoji} #{suggestion[:message]}\n"
    end
    
    message += "\nЧто выберешь?"
    
    message
  end

  def build_general_notification_message(actions, context)
    message = "🤖 *Рекомендация от AI*\n\n"
    
    actions.each do |action|
      confidence_emoji = action[:confidence] > 0.8 ? '🎯' : action[:confidence] > 0.6 ? '✅' : '💭'
      action_text = action[:action].humanize
      
      message += "#{confidence_emoji} #{action_text}\n"
      message += "   Уверенность: #{(action[:confidence] * 100).round}%\n\n"
    end
    
    message += "Попробуй одно из предложений!"
    
    message
  end

  # Helper methods
  def generate_morning_suggestions(context)
    pending_plans = @user.entries.plans.where(dashboard_status: ['new', 'triaged']).count
    new_ideas = @user.entries.ideas.where(dashboard_status: 'new').count
    
    recommendations = []
    
    if pending_plans > 0
      recommendations << "Просмотри #{pending_plans} незавершенных задач"
    end
    
    if new_ideas > 0
      recommendations << "Преврати #{new_ideas} идей в планы"
    end
    
    if pending_plans == 0 && new_ideas == 0
      recommendations << "Создай план на день"
      recommendations << "Подумай о приоритетах"
    end
    
    temporal = context[:temporal_context]
    if temporal[:energy_level] == 'high'
      recommendations << "Используй высокую энергию для сложных задач"
    end
    
    {
      pending_tasks: pending_plans,
      new_ideas: new_ideas,
      recommendations: recommendations.first(3)
    }
  end

  def should_send_morning_planning?(context)
    # Проверяем активность за последние дни
    behavioral = context[:behavioral_context]
    return true if behavioral[:hours_since_last_activity] > 12 # Давно не было активности
    
    # Проверяем, есть ли что планировать
    has_planning_items = @user.entries.where(dashboard_status: ['new', 'triaged']).exists?
    return true if has_planning_items
    
    # Если продуктивный пользователь, всегда предлагаем планирование
    streak = behavioral[:current_streak]
    return true if streak[:streak_type] == 'active' && streak[:duration] >= 3
    
    false
  end

  def send_notification(message)
    Telegram::BotService.send_message(
      chat_id: @user.telegram_id,
      text: message,
      parse_mode: 'Markdown'
    )
  end

  def record_notification(type)
    Rails.cache.write(
      "notification_#{@user.id}_#{type}_#{Date.current}",
      Time.current,
      expires_in: 24.hours
    )
  end

  def notification_sent_today?(type)
    Rails.cache.exist?("notification_#{@user.id}_#{type}_#{Date.current}")
  end

  def recent_notification_sent?(type, duration)
    last_sent = Rails.cache.read("notification_#{@user.id}_#{type}_recent")
    return false unless last_sent
    
    Time.current - last_sent < duration
  end

  def morning_time?
    hour = Time.current.hour
    hour.between?(7, 10)
  end

  def afternoon_time?
    hour = Time.current.hour
    hour.between?(13, 16)
  end

  def evening_time?
    hour = Time.current.hour
    hour.between?(18, 21)
  end
end
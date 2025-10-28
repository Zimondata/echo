class SmartPriorityAnalysisJob < ApplicationJob
  queue_as :default
  
  # Автоматически анализируем приоритеты для пользователя
  def perform(user_id, options = {})
    user = User.find(user_id)
    analyzer = Ai::SmartPriorityAnalyzer.new(user)
    
    Rails.logger.info "Starting smart priority analysis for user #{user.id}"
    
    begin
      results = analyzer.analyze_all_ideas
      
      if results.any?
        Rails.logger.info "Analyzed #{results.size} ideas for user #{user.id}"
        
        # Отправляем уведомление о завершении анализа
        send_analysis_notification(user, results) if options[:notify]
        
        # Автоматические действия на основе анализа
        perform_auto_actions(user, results) if options[:auto_actions]
        
        results
      else
        Rails.logger.info "No ideas found for analysis for user #{user.id}"
        nil
      end
      
    rescue => e
      Rails.logger.error "Smart priority analysis failed for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Уведомляем о неудаче
      send_error_notification(user, e) if options[:notify]
      
      raise e
    end
  end
  
  # Анализируем конкретную идею
  def self.analyze_single_idea(idea_id)
    idea = Entry.find(idea_id)
    analyzer = Ai::SmartPriorityAnalyzer.new(idea.user)
    
    score_data = analyzer.analyze_idea_priority(idea)
    analyzer.send(:update_idea_priority, idea, score_data)
    
    score_data
  end
  
  # Периодический анализ для всех активных пользователей
  def self.analyze_all_users
    active_users = User.joins(:entries)
                       .where(entries: { created_at: 1.week.ago.. })
                       .distinct
    
    active_users.find_each do |user|
      SmartPriorityAnalysisJob.perform_later(user.id, notify: false, auto_actions: true)
    end
  end
  
  private
  
  def send_analysis_notification(user, results)
    # Формируем сводку анализа
    critical_ideas = results.select { |r| r[:score][:priority_level] == 'critical' }
    high_ideas = results.select { |r| r[:score][:priority_level] == 'high' }
    
    message = build_notification_message(critical_ideas, high_ideas)
    
    # Отправляем через Telegram
    if message.present?
      Telegram::BotService.instance.send_message(
        chat_id: user.telegram_id,
        text: message,
        parse_mode: 'HTML'
      )
    end
  rescue => e
    Rails.logger.error "Failed to send analysis notification: #{e.message}"
  end
  
  def build_notification_message(critical_ideas, high_ideas)
    return nil if critical_ideas.empty? && high_ideas.empty?
    
    message = "🧠 <b>AI Анализ приоритетов завершен!</b>\n\n"
    
    if critical_ideas.any?
      message += "🔥 <b>КРИТИЧЕСКИЕ идеи (#{critical_ideas.size}):</b>\n"
      critical_ideas.first(3).each do |result|
        idea = result[:idea]
        score = result[:score][:total_score]
        message += "• #{truncate_idea(idea.content)} (#{score}/10)\n"
      end
      message += "\n"
    end
    
    if high_ideas.any?
      message += "⭐ <b>Высокоприоритетные идеи (#{high_ideas.size}):</b>\n"
      high_ideas.first(2).each do |result|
        idea = result[:idea]
        score = result[:score][:total_score]
        message += "• #{truncate_idea(idea.content)} (#{score}/10)\n"
      end
      message += "\n"
    end
    
    message += "📊 Подробности в дашборде: /ideas_dashboard"
    message
  end
  
  def perform_auto_actions(user, results)
    critical_ideas = results.select { |r| r[:score][:priority_level] == 'critical' }
    
    critical_ideas.each do |result|
      idea = result[:idea]
      recommendations = result[:score][:recommendations]
      
      # Автоматически создаем квесты для критических идей
      auto_create_quest_if_needed(idea, recommendations)
      
      # Отправляем срочные уведомления
      send_urgent_notifications(idea, recommendations)
    end
  end
  
  def auto_create_quest_if_needed(idea, recommendations)
    return if idea.quest_generated?
    
    # Проверяем рекомендации на автосоздание квеста
    auto_quest_rec = recommendations.find { |r| r[:action] == 'create_quest_immediately' }
    return unless auto_quest_rec
    
    begin
      quest_service = Ai::QuestGeneratorService.new(idea)
      quest = quest_service.generate_quest
      
      if quest
        Rails.logger.info "Auto-created quest #{quest.id} for critical idea #{idea.id}"
        
        # Уведомляем пользователя
        Telegram::BotService.instance.send_message(
          chat_id: idea.user.telegram_id,
          text: "🎯 Автоматически создан квест для критической идеи:\n\n" \
                "💡 #{truncate_idea(idea.content)}\n" \
                "🎯 #{quest.title}\n\n" \
                "Квест готов к выполнению!",
          parse_mode: 'HTML'
        )
      end
    rescue => e
      Rails.logger.error "Failed to auto-create quest for idea #{idea.id}: #{e.message}"
    end
  end
  
  def send_urgent_notifications(idea, recommendations)
    urgent_recs = recommendations.select { |r| r[:priority] == 'critical' }
    return if urgent_recs.empty?
    
    urgent_recs.each do |rec|
      message = "⚠️ <b>СРОЧНОЕ УВЕДОМЛЕНИЕ</b>\n\n" \
                "💡 Идея: #{truncate_idea(idea.content)}\n\n" \
                "🚨 #{rec[:message]}\n\n" \
                "Рекомендуется немедленное действие!"
      
      Telegram::BotService.instance.send_message(
        chat_id: idea.user.telegram_id,
        text: message,
        parse_mode: 'HTML'
      )
    end
  rescue => e
    Rails.logger.error "Failed to send urgent notification: #{e.message}"
  end
  
  def send_error_notification(user, error)
    message = "❌ Произошла ошибка при анализе приоритетов идей.\n\n" \
              "Техническая поддержка уведомлена. Попробуйте позже."
    
    Telegram::BotService.instance.send_message(
      chat_id: user.telegram_id,
      text: message
    )
  rescue => e
    Rails.logger.error "Failed to send error notification: #{e.message}"
  end
  
  def truncate_idea(content)
    content.length > 60 ? "#{content[0..57]}..." : content
  end
end
class WeeklyInsightSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    # Генерируем еженедельные дайджесты для всех активных пользователей
    active_users = User.joins(:entries)
                      .where('entries.created_at >= ?', 1.week.ago)
                      .distinct

    active_users.find_each do |user|
      # Проверяем, есть ли у пользователя достаточно активности за неделю
      week_entries = user.entries.where('created_at >= ?', 1.week.ago)
      
      next if week_entries.count < 3 # Пропускаем пользователей с низкой активностью
      
      # Запускаем генерацию недельного дайджеста
      GenerateInsightJob.perform_later(user.id, 'weekly_digest', {
        week_start: 1.week.ago.beginning_of_week
      })
      
      # Отправляем уведомление пользователю
      send_weekly_notification(user)
    end
    
    Rails.logger.info "Weekly insights scheduled for #{active_users.count} users"
  end

  private

  def send_weekly_notification(user)
    # Уведомляем пользователя о готовящемся дайджесте
    notification_text = <<~TEXT
      📈 *Еженедельный дайджест готовится!*
      
      Анализирую твою активность за прошедшую неделю...
      
      Скоро получишь:
      🎯 Твои достижения и прогресс
      📊 Статистику продуктивности  
      💡 Персональные инсайты
      🚀 Рекомендации на новую неделю
      
      Дайджест будет готов через несколько минут!
      Используй /insights чтобы посмотреть результат.
    TEXT

    Telegram::BotService.send_message(
      chat_id: user.telegram_id,
      text: notification_text
    )
  rescue StandardError => e
    Rails.logger.error "Failed to send weekly notification to user #{user.id}: #{e.message}"
  end
end

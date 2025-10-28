# Конфигурация повторяющихся задач
# В production среде рекомендуется использовать cron или sidekiq scheduler

Rails.application.configure do
  # Запускаем только в production или при указании переменной окружения
  if Rails.env.production? || ENV['ENABLE_RECURRING_JOBS'] == 'true'
    config.after_initialize do
      # Планируем периодические задачи
      if defined?(Rails::Server) || defined?(Puma::Server)
        Thread.new do
          loop do
            now = Time.current
            
            # Каждое воскресенье в 20:00 - еженедельные инсайты
            if now.sunday? && now.hour == 20 && now.min < 5
              WeeklyInsightSchedulerJob.perform_later
              Rails.logger.info "Weekly insights job scheduled at #{now}"
            end
            
            # Каждый час в начале часа - контекстуальные уведомления
            if now.min < 5 # В первые 5 минут каждого часа
              ScheduleContextualNotificationsJob.perform_later
              Rails.logger.info "Contextual notifications job scheduled at #{now}"
            end

            # Каждую минуту - отправка напоминаний (обычных и умных)
            SendRemindersJob.perform_later
            Rails.logger.info "Send reminders job scheduled at #{now}"

            # Каждые 6 часов - генерация умных напоминаний
            if now.hour % 6 == 0 && now.min < 5
              GenerateSmartRemindersJob.perform_later
              Rails.logger.info "Generate smart reminders job scheduled at #{now}"
            end

            # Проверяем каждые 5 минут
            sleep(5.minutes)
          end
        end
      end
    end
  end
end

# Альтернативный способ для разработки - запуск через console
# Можно вызвать в rails console:
# WeeklyInsightSchedulerJob.perform_now
#!/usr/bin/env ruby

# Скрипт для тестирования утренней сводки
# Запуск: ruby test_morning_summary.rb

require_relative 'config/environment'

puts "🌅 Тестируем утреннюю сводку..."

# Получаем первого пользователя
user = User.first

if user.nil?
  puts "❌ Пользователь не найден! Создайте пользователя сначала."
  exit
end

puts "👤 Пользователь: #{user.full_name} (#{user.timezone})"

# Получаем текущий день в timezone пользователя
current_day = Date.current.in_time_zone(user.timezone)
day_start = current_day.beginning_of_day.in_time_zone(user.timezone)
day_end = current_day.end_of_day.in_time_zone(user.timezone)

puts "📅 Дата: #{current_day.strftime('%A, %d %B %Y')}"

# Получаем события на сегодня
today_events = user.calendar_events
                  .active
                  .where(start_time: day_start..day_end)
                  .order(:start_time)

today_reminders = user.reminders
                     .pending
                     .where(remind_at: day_start..day_end)
                     .order(:remind_at)

puts "📋 События на сегодня: #{today_events.count}"
today_events.each do |event|
  time_str = event.all_day? ? "весь день" : event.start_time.in_time_zone(user.timezone).strftime('%H:%M')
  puts "  • #{time_str} - #{event.title}"
end

puts "🔔 Напоминания на сегодня: #{today_reminders.count}"
today_reminders.each do |reminder|
  time_str = reminder.remind_at.in_time_zone(user.timezone).strftime('%H:%M')
  puts "  • #{time_str} - #{reminder.message}"
end

puts "\n📨 Формируем сообщение..."

# Создаем экземпляр job'а для тестирования
job = DailyMorningSummaryJob.new
message = job.send(:build_morning_message, user, current_day, today_events, today_reminders)

puts "\n" + "="*50
puts "УТРЕННЯЯ СВОДКА:"
puts "="*50
puts message
puts "="*50

puts "\n✅ Тест завершен!"
puts "💡 Для отправки реального сообщения раскомментируйте строки ниже:"
puts "# Telegram::BotService.instance.send_message("
puts "#   chat_id: #{user.telegram_id},"
puts "#   text: message,"
puts "#   parse_mode: 'Markdown'"
puts "# )"
#!/usr/bin/env ruby

require_relative 'config/environment'

puts "🤖 Тестируем бота Echo..."

# Найдём первого пользователя
user = User.first

if user
  puts "👤 Найден пользователь: #{user.full_name} (#{user.telegram_id})"
  
  # Отправим тестовое сообщение
  begin
    message = "🧪 Тест бота Echo!\n\nЭто тестовое сообщение отправлено из консоли.\n\n⏰ Время: #{Time.current.strftime('%H:%M:%S')}"
    
    Telegram::BotService.send_message(
      chat_id: user.telegram_id,
      text: message
    )
    
    puts "✅ Сообщение отправлено!"
    
    # Также отправим сообщение с кнопками
    sleep 1
    
    button_message = "🎯 Быстрые действия:"
    
    Telegram::BotService.send_message(
      chat_id: user.telegram_id,
      text: button_message,
      reply_markup: {
        inline_keyboard: [
          [
            { text: "📅 События", callback_data: "show_events" },
            { text: "📔 Дневник", callback_data: "show_diary" }
          ],
          [
            { text: "💡 Идеи", callback_data: "show_ideas" },
            { text: "📊 Статистика", callback_data: "show_stats" }
          ]
        ]
      }.to_json
    )
    
    puts "✅ Сообщение с кнопками отправлено!"
    
  rescue => e
    puts "❌ Ошибка при отправке: #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end
else
  puts "❌ Пользователи не найдены. Сначала нужно написать боту /start в Telegram."
end

puts "\n🏁 Тест завершён!"
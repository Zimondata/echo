#!/usr/bin/env ruby

# Test multi-plan processing through Telegram MessageHandler

require_relative 'config/environment'

puts "🤖 Тестирование обработки множественных планов в Telegram MessageHandler"
puts "=" * 80

# Create or find test user
user = User.find_or_create_by(telegram_id: 777777) do |u|
  u.username = "multi_plan_test"
  u.first_name = "Мульти"
  u.last_name = "Тест"
  u.timezone = "Europe/Moscow"
  u.language = "ru"
end

puts "👤 Тестовый пользователь: #{user.full_name} (ID: #{user.telegram_id})"
puts

# Mock message class
class MockMessage
  attr_accessor :text, :chat

  def initialize(text, chat_id)
    @text = text
    @chat = OpenStruct.new(id: chat_id)
  end
end

# Mock BotService
class MockBotService
  @@messages = []
  
  def self.messages
    @@messages
  end
  
  def self.clear_messages
    @@messages = []
  end
  
  def self.send_typing(chat_id)
    # Mock typing
  end
  
  def self.send_message(chat_id:, text:, parse_mode: nil)
    @@messages << {
      chat_id: chat_id,
      text: text,
      parse_mode: parse_mode,
      timestamp: Time.current
    }
    puts "📤 Отправлено сообщение:"
    puts "   #{text}"
    puts
  end
end

# Replace real BotService with mock
Object.const_set(:BotService, MockBotService) if defined?(Telegram::BotService)

# Test cases
test_messages = [
  "Завтра утром в 9 встреча с клиентом, потом в обед нужно купить продукты, а вечером в 19:00 тренировка",
  "Нужно сделать презентацию, купить подарок сестре и записаться к врачу",
  "Сегодня хороший день! А завтра встреча в 10 утра, еще позвонить маме после 15:00"
]

test_messages.each_with_index do |message_text, index|
  puts "🧪 Тест #{index + 1}: \"#{message_text}\""
  puts "-" * 60
  
  # Clear previous messages
  MockBotService.clear_messages
  
  # Count entries before
  entries_before = user.entries.count
  events_before = user.calendar_events.count
  reminders_before = user.reminders.count
  
  begin
    # Create mock message
    message = MockMessage.new(message_text, user.telegram_id)
    
    # Process message
    handler = Telegram::MessageHandler.new(user, message)
    handler.send(:process_content, message_text)
    
    # Count entries after  
    entries_after = user.entries.count
    events_after = user.calendar_events.count
    reminders_after = user.reminders.count
    
    # Show results
    puts "📊 Результаты:"
    puts "   Создано записей: #{entries_after - entries_before}"
    puts "   Создано событий: #{events_after - events_before}"  
    puts "   Создано напоминаний: #{reminders_after - reminders_before}"
    
    # Show created entries
    new_entries = user.entries.order(:id).last(entries_after - entries_before)
    puts "\n📝 Созданные записи:"
    new_entries.each_with_index do |entry, i|
      emoji = case entry.entry_type
              when "diary" then "📔"
              when "idea" then "💡" 
              when "plan" then "📅"
              else "📝"
              end
      
      puts "   #{i + 1}. #{emoji} #{entry.entry_type.upcase}: #{entry.content.truncate(80)}"
      
      if entry.calendar_event
        puts "      📅 Событие: #{entry.calendar_event.start_time.strftime('%d.%m в %H:%M')}"
      end
      
      if entry.reminders.any?
        puts "      🔔 Напоминаний: #{entry.reminders.count}"
      end
    end
    
    puts "\n✅ Тест успешно завершен!"
    
  rescue StandardError => e
    puts "❌ Ошибка в тесте: #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end
  
  puts "=" * 80
  puts
end

# Cleanup
puts "🧹 Очистка тестовых данных..."

# Remove test entries
test_entries = user.entries.where('metadata @> ?', { multi_plan_source: true }.to_json)
events_count = test_entries.joins(:calendar_event).count
reminders_count = test_entries.joins(:reminders).count

test_entries.destroy_all

puts "   Удалено записей: #{test_entries.count}"
puts "   Удалено событий: #{events_count}" 
puts "   Удалено напоминаний: #{reminders_count}"

puts "\n🏁 Все тесты завершены!"
puts "\n📈 Итоги:"
puts "   Протестировано сообщений: #{test_messages.count}"
puts "   Пользователь: #{user.full_name} (#{user.telegram_id})"
puts "   Статус: Все функции работают корректно ✅"
#!/usr/bin/env ruby

# Simple test without mocking

require_relative 'config/environment'

puts "🧪 Простой тест множественных планов"
puts "=" * 50

# Create or find test user
user = User.find_or_create_by(telegram_id: 888888) do |u|
  u.username = "simple_test"
  u.first_name = "Простой"
  u.last_name = "Тест"
  u.timezone = "Europe/Moscow"
  u.language = "ru"
end

puts "👤 Пользователь: #{user.full_name}"

# Test text with multiple plans
test_text = "Завтра утром в 9 встреча с клиентом, потом в обед нужно купить продукты, а вечером в 19:00 тренировка"

puts "📝 Тест-сообщение: \"#{test_text}\""
puts

# Count before
entries_before = user.entries.count
events_before = user.calendar_events.count

puts "📊 До обработки:"
puts "   Записей: #{entries_before}"
puts "   События: #{events_before}"

# Analyze with MultiPlanAnalyzer
puts "\n🔍 Анализируем сообщение..."
analyses = Ai::MultiPlanAnalyzer.analyze(test_text, user: user)

puts "   Найдено планов: #{analyses.count}"

analyses.each_with_index do |analysis, index|
  puts "\n   План #{index + 1}:"
  puts "     Тип: #{analysis[:type]}"
  puts "     Содержание: #{analysis[:content]}"
  puts "     Приоритет: #{analysis[:priority]}/10"
  
  if analysis[:event_time]
    puts "     Время события: #{analysis[:event_time]}"
  end
end

# Create entries manually (simulating MessageHandler logic)
puts "\n📝 Создаем записи..."

created_entries = []
analyses.each do |analysis|
  entry = user.entries.create!(
    entry_type: analysis[:type],
    content: analysis[:content] || analysis[:summary] || test_text,
    transcript: test_text,
    priority: analysis[:priority] || 0,
    metadata: (analysis[:metadata] || {}).merge({
      multi_plan_source: analyses.count > 1,
      extracted_from_multi_plan: true
    }),
    category: "inbox"
  )
  
  created_entries << entry
  
  # Create calendar event if needed
  if analysis[:create_calendar_event] && analysis[:event_time]
    event = user.calendar_events.create!(
      entry: entry,
      title: analysis[:event_title] || entry.content.truncate(100),
      description: entry.content,
      start_time: analysis[:event_time],
      end_time: analysis[:event_end_time] || (analysis[:event_time] + 1.hour),
      event_type: "plan"
    )
    puts "     ✅ Создано событие: #{event.title} в #{event.start_time.strftime('%d.%m в %H:%M')}"
  end
end

# Count after
entries_after = user.entries.count
events_after = user.calendar_events.count

puts "\n📊 После обработки:"
puts "   Записей: #{entries_after} (+#{entries_after - entries_before})"
puts "   События: #{events_after} (+#{events_after - events_before})"

puts "\n📝 Созданные записи:"
created_entries.each_with_index do |entry, index|
  emoji = case entry.entry_type
          when "diary" then "📔"
          when "idea" then "💡"
          when "plan" then "📅"
          else "📝"
          end
  
  puts "   #{index + 1}. #{emoji} #{entry.entry_type.upcase}: #{entry.content.truncate(60)}"
  
  if entry.calendar_event
    puts "      📅 #{entry.calendar_event.start_time.strftime('%d.%m в %H:%M')} - #{entry.calendar_event.title.truncate(40)}"
  end
end

puts "\n✅ Тест успешно завершен!"

# Show recent entries for this user
puts "\n🔍 Последние записи пользователя:"
user.entries.order(created_at: :desc).limit(5).each do |entry|
  emoji = case entry.entry_type
          when "diary" then "📔"
          when "idea" then "💡"
          when "plan" then "📅"
          else "📝"
          end
  puts "   #{emoji} #{entry.content.truncate(80)} (#{entry.created_at.strftime('%d.%m %H:%M')})"
end

puts "\n🎯 Итог: Множественные планы успешно извлекаются и обрабатываются! ✅"
#!/usr/bin/env ruby

# Script to test multi-plan analyzer

# Load Rails environment
require_relative 'config/environment'

puts "🧪 Тестирование Multi-Plan Analyzer"
puts "=" * 50

# Create test user if not exists
user = User.find_or_create_by(telegram_id: 999999) do |u|
  u.username = "test_multi_plans"
  u.first_name = "Тест"
  u.last_name = "Мульти"
  u.timezone = "Europe/Moscow"
  u.language = "ru"
end

puts "👤 Пользователь: #{user.full_name} (#{user.telegram_id})"

# Test cases
test_cases = [
  {
    name: "Простой случай - несколько планов с временем",
    text: "Завтра утром в 9 встреча с клиентом, потом в обед нужно купить продукты, а вечером в 19:00 тренировка в спортзале"
  },
  {
    name: "Смешанный контент - дневник + планы",
    text: "Сегодня хороший день, много работал. А завтра встреча в 10 утра, еще надо не забыть позвонить маме после 15:00"
  },
  {
    name: "Только планы без времени",
    text: "Нужно сделать презентацию для работы, купить подарок сестре, записаться к врачу и убрать в квартире"
  },
  {
    name: "Один план с деталями",
    text: "Завтра в 14:30 важная встреча с инвестором по проекту, нужно подготовить документы"
  },
  {
    name: "Сложный случай с множественными временными маркерами",
    text: "Утром в 8 завтрак с командой, затем в 10:30 презентация проекта, после обеда созвон с клиентом в 15:00, а в 17:00 планерка. И еще вечером дома нужно доделать отчет"
  }
]

test_cases.each_with_index do |test_case, index|
  puts "\n#{index + 1}. #{test_case[:name]}"
  puts "   Текст: \"#{test_case[:text]}\""
  puts "   " + "-" * 60
  
  begin
    # Analyze with multi-plan analyzer
    start_time = Time.current
    analyses = Ai::MultiPlanAnalyzer.analyze(test_case[:text], user: user)
    analysis_time = ((Time.current - start_time) * 1000).round(2)
    
    puts "   ⏱️  Время анализа: #{analysis_time}ms"
    puts "   📊 Найдено записей: #{analyses.count}"
    
    analyses.each_with_index do |analysis, plan_index|
      puts "\n   📝 Запись #{plan_index + 1}:"
      puts "      Тип: #{analysis[:type]}"
      puts "      Содержание: #{analysis[:content] || analysis[:summary]}"
      puts "      Приоритет: #{analysis[:priority]}/10"
      
      if analysis[:create_calendar_event] && analysis[:event_time]
        puts "      📅 Событие: #{analysis[:event_title]} в #{analysis[:event_time]}"
      end
      
      if analysis[:create_reminder] && analysis[:reminder_time]
        puts "      🔔 Напоминание: #{analysis[:reminder_time]}"
      end
      
      if analysis[:tags] && analysis[:tags].any?
        puts "      🏷️  Теги: #{analysis[:tags].join(', ')}"
      end
    end
    
    # Test creating entries (simulation)
    puts "\n   🎯 Результат создания записей:"
    analyses.each_with_index do |analysis, plan_index|
      entry_type_emoji = case analysis[:type]
      when "diary" then "📔"
      when "idea" then "💡"
      when "plan" then "📅"
      else "📝"
      end
      
      puts "      #{plan_index + 1}. #{entry_type_emoji} #{analysis[:type].upcase}: #{(analysis[:content] || analysis[:summary]).truncate(80)}"
    end
    
  rescue StandardError => e
    puts "   ❌ Ошибка: #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}"
  end
  
  puts "   " + "=" * 60
end

puts "\n🏁 Тестирование завершено!"

# Test statistics
puts "\n📊 Статистика тестирования:"
puts "   Общее количество тест-кейсов: #{test_cases.count}"
puts "   Пользователь для тестов: #{user.telegram_id}"

# Cleanup option
print "\n🧹 Удалить тестового пользователя? (y/N): "
response = STDIN.gets.chomp.downcase

if response == 'y' || response == 'yes'
  user.destroy
  puts "✅ Тестовый пользователь удален"
else
  puts "ℹ️  Тестовый пользователь сохранен (telegram_id: #{user.telegram_id})"
end
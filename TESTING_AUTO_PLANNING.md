# 🤖 Гайд по тестированию автоматического планирования

## 🚀 Быстрый старт

### 1️⃣ Создание тестовых данных

```bash
# Запуск готового скрипта с тестовыми данными
rails runner test_auto_planning.rb
```

### 2️⃣ Ручное создание данных через консоль

```bash
bin/rails console
```

```ruby
# Создаем тестового пользователя
user = User.create!(
  telegram_id: 888888,
  username: "auto_planner",
  first_name: "Авто",
  last_name: "Планер",
  timezone: "Europe/Moscow"
)

# Добавляем идеи для автоматического планирования
user.entries.create!(
  content: "Идея: создать мобильное приложение для фитнеса",
  entry_type: "idea",
  category: "projects",
  dashboard_status: "new",
  created_at: 2.days.ago
)

user.entries.create!(
  content: "Идея: написать статью о продуктивности",
  entry_type: "idea", 
  category: "work",
  dashboard_status: "new",
  created_at: 1.day.ago
)

# Добавляем незавершенные планы
user.entries.create!(
  content: "Закончить отчет по проекту до пятницы",
  entry_type: "plan",
  category: "work",
  dashboard_status: "triaged",
  priority: 10,
  created_at: 3.days.ago
)

# Добавляем события в календарь для тестирования конфликтов
user.calendar_events.create!(
  title: "Встреча с командой",
  start_time: Time.current.tomorrow.change(hour: 10),
  end_time: Time.current.tomorrow.change(hour: 12),
  category: "work"
)

user.calendar_events.create!(
  title: "Обед",
  start_time: Time.current.tomorrow.change(hour: 11, min: 30),
  end_time: Time.current.tomorrow.change(hour: 12, min: 30),
  category: "life"
)
```

## 📱 Тестирование через Telegram

### Команды автоматического планирования

```bash
/plan           # Создать план на день
/plan weekly    # Создать план на неделю
/optimize       # Оптимизировать расписание
/suggest        # Умные предложения
/autoplan       # Полное автопланирование
```

### Примеры использования

1. **Базовое планирование:**
   ```
   /plan
   ```
   Ожидаемый результат: План на сегодня с расписанием задач

2. **Недельное планирование:**
   ```
   /plan weekly
   ```
   Ожидаемый результат: Распределение задач по дням недели

3. **Оптимизация:**
   ```
   /optimize
   ```
   Ожидаемый результат: Оптимизированное расписание с рекомендациями

4. **Автопланирование:**
   ```
   /autoplan
   ```
   Ожидаемый результат: Создание планов из идей + дневное расписание

## 🔧 Тестирование компонентов в консоли

### Ai::PlanGenerator

```ruby
user = User.find_by(telegram_id: 888888)

# Тестируем генерацию плана из идеи
plan_data = Ai::PlanGenerator.call(
  user: user,
  idea_content: "Создать личный блог о программировании",
  context: "Тестирование генератора планов"
)

puts "Заголовок плана: #{plan_data[:plan_title]}"
puts "Количество задач: #{plan_data[:tasks].count}"
puts "Приоритет: #{plan_data[:priority]}"

plan_data[:tasks].each_with_index do |task, i|
  puts "Задача #{i+1}: #{task[:title]}"
  puts "  Время: #{task[:estimated_time]} мин"
  puts "  Приоритет: #{task[:priority]}"
end
```

### Ai::ScheduleOptimizer

```ruby
# Подготавливаем задачи для оптимизации
tasks = [
  {
    id: 1,
    title: "Написать код",
    estimated_time: 120,
    priority: "high",
    category: "work"
  },
  {
    id: 2,
    title: "Почитать документацию",
    estimated_time: 60,
    priority: "medium", 
    category: "work"
  }
]

# Тестируем оптимизацию
result = Ai::ScheduleOptimizer.call(
  user: user,
  tasks: tasks,
  date_range: Date.current..Date.current
)

puts "Оптимизированные задачи:"
result[:optimized_tasks].each do |task|
  puts "#{task[:title]} в #{task[:suggested_start_time]&.strftime('%H:%M')}"
  puts "  Уверенность: #{task[:confidence_score]}%"
end

puts "\nРекомендации:"
result[:recommendations].each do |rec|
  puts "- #{rec[:message]}"
end
```

### Ai::ContextAnalyzer

```ruby
# Анализируем контекст пользователя
context = Ai::ContextAnalyzer.analyze_context(user: user)

puts "Временной контекст:"
puts "  Время: #{context[:temporal_context][:time_category]}"
puts "  Энергия: #{context[:temporal_context][:energy_level]}"

puts "\nПоведенческий контекст:"
puts "  Последняя активность: #{context[:behavioral_context][:hours_since_last_activity]} ч. назад"
puts "  Уровень вовлеченности: #{context[:behavioral_context][:engagement_level]}"

puts "\nПредложения:"
context[:suggestions].each do |suggestion|
  puts "- #{suggestion[:message]} (#{suggestion[:priority]})"
end
```

### Ai::AutoPlanner

```ruby
# Полное автоматическое планирование
plan = Ai::AutoPlanner.generate_daily_plan(
  user: user,
  options: { include_context: true }
)

puts "План: #{plan[:summary]}"
puts "Вероятность успеха: #{plan[:success_probability]}%"
puts "Общее время: #{plan[:estimated_total_time]} ч."

puts "\nЗапланированные задачи:"
plan[:scheduled_tasks]&.each do |task|
  time_str = task[:suggested_start_time]&.strftime('%H:%M') || "время не указано"
  puts "#{time_str} - #{task[:title]} (#{task[:estimated_time]} мин)"
end

# Умные предложения
suggestions = Ai::AutoPlanner.suggest_next_actions(user: user)

puts "\nКонтекст: #{suggestions[:context_summary]}"
puts "\nРекомендации сейчас:"
suggestions[:immediate_suggestions]&.each do |s|
  puts "- #{s[:message]}"
end
```

## 🤖 Тестирование уведомлений

### Ручной запуск контекстуальных уведомлений

```ruby
user = User.find_by(telegram_id: 888888)

# Утреннее планирование
ContextualNotificationJob.perform_now(user.id, 'morning_planning')

# Оптимизация энергии
ContextualNotificationJob.perform_now(user.id, 'energy_optimization')

# Проверка продуктивности
ContextualNotificationJob.perform_now(user.id, 'productivity_check')

# Вечерняя рефлексия  
ContextualNotificationJob.perform_now(user.id, 'daily_reflection')

# Контекстуальные предложения
ContextualNotificationJob.perform_now(user.id, 'context_suggestions')
```

### Тестирование планировщика уведомлений

```ruby
# Запускаем планировщик для всех пользователей
ScheduleContextualNotificationsJob.perform_now

# Или для конкретного пользователя (приватный метод, нужен обход)
job = ScheduleContextualNotificationsJob.new
job.send(:schedule_user_notifications, user)
```

## 🎯 Что проверять

### ✅ AI Plan Generator работает корректно
- [ ] Генерирует планы из идей
- [ ] Создает реалистичные задачи с временными рамками
- [ ] Определяет приоритеты правильно
- [ ] Fallback работает при ошибках API

### ✅ Schedule Optimizer оптимизирует расписание
- [ ] Учитывает паттерны пользователя
- [ ] Находит оптимальное время для задач
- [ ] Избегает конфликтов с календарем
- [ ] Предлагает альтернативные временные слоты

### ✅ Context Analyzer анализирует контекст
- [ ] Правильно определяет время дня и энергию
- [ ] Анализирует поведенческие паттерны
- [ ] Генерирует релевантные предложения
- [ ] Учитывает продуктивность пользователя

### ✅ Auto Planner объединяет все компоненты
- [ ] Создает дневные планы
- [ ] Генерирует недельные планы
- [ ] Предлагает умные действия
- [ ] Автоматически создает задачи из идей

### ✅ Telegram команды работают
- [ ] `/plan` создает дневной план
- [ ] `/plan weekly` создает недельный план
- [ ] `/optimize` оптимизирует расписание
- [ ] `/suggest` показывает предложения
- [ ] `/autoplan` запускает полное планирование

### ✅ Контекстуальные уведомления отправляются
- [ ] Утреннее планирование (7-10 утра)
- [ ] Оптимизация энергии (при высокой энергии)
- [ ] Проверка продуктивности (13-16 часов)
- [ ] Вечерняя рефлексия (18-21 часов)
- [ ] Контекстуальные предложения (по приоритету)

## 🐛 Troubleshooting

### Проблема: AI не генерирует планы
**Решение:** Проверь наличие OpenAI API ключа в credentials

### Проблема: Нет задач для планирования
**Решение:** Создай тестовые идеи и планы со статусом 'new' или 'triaged'

### Проблема: Оптимизация не работает
**Решение:** Убедись, что у пользователя есть история записей для анализа паттернов

### Проблема: Уведомления не отправляются
**Решение:** Включи ENABLE_RECURRING_JOBS=true в .env файле

### Проблема: Команды не работают в Telegram
**Решение:** Проверь webhook и убедись, что сервер запущен

## 📊 Примеры ожидаемых результатов

### Дневной план
```
📋 План на 13.10.2024: 3 задачи, ~3.5 часов работы

🔍 Контекст:
• Утром Monday, энергия: high, последняя активность: 12 ч. назад

🎯 Приоритеты:
• Утренние приоритеты (важность: 90%)

⏰ Расписание задач:
🎯 Написать код для фитнес-приложения в 09:00
   └ 120 мин, high приоритет
   💡 9:00 - одно из ваших самых активных времен

✅ Почитать документацию в 14:00
   └ 60 мин, medium приоритет

🎯 Вероятность успеха: 85%
⏱ Общее время: ~3.0 ч.
```

### Умные предложения
```
💡 Умные предложения утром

📍 Текущий контекст:
Morning Monday, энергия: high, последняя активность: 12 ч. назад

⚡ Рекомендации сейчас:
🔥 Сейчас у вас высокий уровень энергии! Самое время заняться важной задачей.

🎯 Оптимальные действия:
• Plan day
  █████ 90%
• Tackle complex task  
  ████░ 80%
```

Удачного тестирования! 🚀
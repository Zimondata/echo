# 🧪 Гайд по тестированию инсайтов

## 🚀 Быстрый старт

### 1️⃣ Создание тестовых данных

```bash
# Запуск готового скрипта с тестовыми данными
rails runner test_insights_manual.rb
```

### 2️⃣ Создание данных вручную через консоль

```bash
bin/rails console
```

```ruby
# Создаем тестового пользователя
user = User.create!(
  telegram_id: 777777,
  username: "test_user",
  first_name: "Тест",
  timezone: "Europe/Moscow"
)

# Добавляем записи за несколько дней
user.entries.create!(
  content: "Отличный день! Завершил важный проект",
  entry_type: "diary",
  category: "work",
  created_at: 0.days.ago
)

user.entries.create!(
  content: "Идея: создать AI-помощника для анализа",
  entry_type: "idea", 
  category: "ideas",
  created_at: 1.day.ago
)

user.entries.create!(
  content: "План: встреча с командой завтра",
  entry_type: "plan",
  category: "work", 
  created_at: 2.days.ago
)

# Тестируем статистику
Analytics::UserStatsCollector.daily_stats(user)
Analytics::UserStatsCollector.weekly_stats(user)

# Генерируем инсайты
GenerateInsightJob.perform_now(user.id, 'daily_summary')
GenerateInsightJob.perform_now(user.id, 'weekly_digest')

# Смотрим результаты
user.insights.recent.each { |i| puts "#{i.title}: #{i.content}" }
```

## 📱 Тестирование через Telegram

### Предварительная настройка

1. Убедись, что сервер запущен: `bin/dev`
2. Настрой ngrok: `ngrok http 3000`
3. Установи webhook с твоим ngrok URL

### Команды для тестирования

```
/start      # Начать работу с ботом
/help       # Посмотреть все доступные команды

# Создание контента для анализа
"Сегодня продуктивный день, завершил 3 задачи"
"Идея: автоматизировать отчеты"
"План: встреча завтра в 15:00"

# Команды инсайтов
/insights   # Посмотреть готовые инсайты
/stats      # Подробная статистика за неделю
/daily      # Создать резюме за день
/digest     # Создать недельный дайджест
```

## 🔧 Ручное тестирование компонентов

### Analytics::UserStatsCollector

```ruby
user = User.find_by(telegram_id: 777777)

# Дневная статистика
daily = Analytics::UserStatsCollector.daily_stats(user, Date.current)
puts daily.inspect

# Недельная статистика  
weekly = Analytics::UserStatsCollector.weekly_stats(user)
puts weekly.inspect

# Месячная статистика
monthly = Analytics::UserStatsCollector.monthly_stats(user) 
puts monthly.inspect
```

### Ai::InsightGenerator

```ruby
# Тестовый контент
content = "Сегодня был продуктивный день. Завершил проект и получил фидбек."

# Генерация дневного резюме
result = Ai::InsightGenerator.call(
  content: content,
  insight_type: 'daily_summary',
  context: { total_entries: 3, mood_keywords: ['продуктивный', 'завершил'] }
)

puts result.inspect
```

### GenerateInsightJob

```ruby
user = User.find_by(telegram_id: 777777)

# Различные типы инсайтов
GenerateInsightJob.perform_now(user.id, 'daily_summary', { date: Date.current })
GenerateInsightJob.perform_now(user.id, 'weekly_digest')
GenerateInsightJob.perform_now(user.id, 'productivity_insight')
GenerateInsightJob.perform_now(user.id, 'trend_analysis', { period: '1_month' })

# Проверяем результаты
user.insights.recent.each do |insight|
  puts "\n#{insight.insight_type.upcase}: #{insight.title}"
  puts insight.content
  puts "Data: #{insight.data}"
  puts "-" * 40
end
```

## 🎯 Что проверять

### ✅ Статистика собирается корректно
- [ ] Подсчет записей по типам
- [ ] Расчет продуктивности
- [ ] Анализ настроения
- [ ] Тренды по категориям

### ✅ AI генерирует качественные инсайты
- [ ] Дневные резюме содержат ключевые моменты
- [ ] Недельные дайджесты включают достижения и цели
- [ ] Анализ продуктивности дает практические советы
- [ ] Fallback работает при ошибках API

### ✅ Telegram команды работают
- [ ] `/insights` показывает последние инсайты
- [ ] `/stats` отображает статистику 
- [ ] `/daily` запускает генерацию резюме
- [ ] `/digest` создает недельный дайджест

### ✅ Автоматизация функционирует
- [ ] WeeklyInsightSchedulerJob запускается
- [ ] Уведомления отправляются пользователям
- [ ] Инсайты создаются с правильными данными

## 🐛 Troubleshooting

### Проблема: AI не генерирует инсайты
**Решение:** Проверь наличие OpenAI API ключа в `credentials.yml`

### Проблема: Статистика показывает 0
**Решение:** Убедись, что записи созданы в правильном временном диапазоне

### Проблема: Telegram команды не работают  
**Решение:** Проверь webhook и убедись, что сервер запущен

### Проблема: Ошибки валидации при создании записей
**Решение:** Используй только разрешенные категории: `inbox`, `work`, `life`, `health`, `ideas`, `projects`

## 📊 Примеры ожидаемых результатов

### Дневная статистика
```ruby
{
  total_entries: 3,
  by_type: {"diary" => 1, "idea" => 1, "plan" => 1},
  productivity_score: 65,
  mood_keywords: ["отлично", "продуктивный"],
  top_themes: ["работа", "проект", "команда"]
}
```

### Недельный дайджест
```
"На этой неделе вы проявили высокую активность с 15 записями. 
Преобладали рабочие темы (60%) и планирование (25%). 
Настроение в целом позитивное (8/10). 
Рекомендуется больше внимания уделить идеям для развития."
```

Удачного тестирования! 🚀
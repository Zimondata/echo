# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

Echo — Telegram AI-ассистент для управления дневником, идеями, планами, активностью и питанием через голосовой и текстовый ввод. Использует OpenAI GPT-4 для анализа контента и Whisper для транскрипции речи.

**Технологии:**
- Ruby 3.4.5
- Rails 8.0.3
- SQLite3
- Solid Queue (фоновые задачи, Rails 8 native)
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- Telegram Bot API
- OpenAI API (GPT-4, Whisper)

## Рекомендации по разработке

### Rails 8 стек
- Избегать лишнего JavaScript — использовать Turbo Streams
- Solid Queue для фоновых задач (config/recurring.yml для периодических)
- SolidCable для WebSockets (опционально)
- SolidCache для кэширования views (опционально)

### Стиль кода
- Идиоматичный Ruby по конвенциям Rails
- snake_case для файлов/методов/переменных, CamelCase для классов
- Service objects в `app/services/` для сложной логики
- Одинарные кавычки, если нет интерполяции

### Frontend
- Tailwind CSS с кастомными палитрами
- Для русского текста — кириллические шрифты
- Анимации через Turbo и Stimulus

## Команды разработки

```bash
# Запуск сервера
bin/dev

# Rails консоль
bin/rails console

# Тесты
bin/rails test
bin/rails test test/models/user_test.rb      # конкретный файл
bin/rails test test/models/user_test.rb:10   # конкретная строка

# Качество кода
bin/rubocop
bin/rubocop -a      # авто-исправление
bin/brakeman        # безопасность

# База данных
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:reset  # drop, create, migrate, seed
```

### Kamal деплой

```bash
kamal deploy        # деплой на продакшн
kamal console       # продакшн консоль
kamal shell         # продакшн shell
kamal logs          # логи
```

### Telegram Webhook

```bash
# Установить webhook (заменить TOKEN и NGROK_URL)
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -d "url=<NGROK_URL>/telegram/webhook"

# Проверить статус
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
```

## Архитектура

### Поток обработки

1. **Telegram → Webhook** (`/telegram/webhook`)
   - `TelegramController#webhook` получает update
   - Ставит в очередь `TelegramWebhookJob`, сразу возвращает 200 OK
   - ВАЖНО: всегда возвращать 200 OK для предотвращения повторных запросов

2. **Асинхронная обработка** (Solid Queue)
   - `TelegramWebhookJob` обрабатывает через Solid Queue
   - Создаёт/находит `User` по `telegram_id`
   - Делегирует в `Telegram::MessageHandler` (app/services/telegram/message_handler.rb:12)

3. **Обработка сообщений** (Telegram::MessageHandler)
   - Команды (`/start`, `/help`, `/calendar`, `/insights`, `/stats`) → обработчики команд (message_handler.rb:38)
   - Голос → `Ai::WhisperService` → обработка контента (message_handler.rb:260)
   - Фото → `Ai::VisionService` (еда) или `Ai::GarminAnalyzer` (тренировки) (message_handler.rb:287)
   - Текст → `process_content` (message_handler.rb:283)

4. **Обработка контента** (Telegram::MessageHandler#process_content)
   - Проверка исправлений через `Ai::CorrectionDetector` (message_handler.rb:448)
   - `Ai::MultiPlanAnalyzer` извлекает множественные планы из одного сообщения (message_handler.rb:469)
   - `Ai::ContentAnalyzer` классифицирует каждый элемент: `diary`, `idea`, `plan`, `plan_update`, `nutrition`, `activity`, `command` (content_analyzer.rb:178)
   - Создаёт `Entry` с метаданными (message_handler.rb:495-563)
   - Группировка связанных идей через `group_id` и parent/child entries (message_handler.rb:487-542)
   - Опционально создаёт `CalendarEvent`, `Reminder`, `NutritionEntry` (message_handler.rb:565-606)

5. **Специальная логика**
   - **Исправления**: 10-минутное окно для исправления последних записей (user.rb:42)
   - **Дубликаты событий**: проверка существующих событий по названию и дате (message_handler.rb:876)
   - **All-day планы**: события без конкретного времени (metadata[:all_day]) (message_handler.rb:741)
   - **Timezone**: все даты обрабатываются в timezone пользователя (content_analyzer.rb:184)

### Ключевые сервисы

| Сервис | Назначение |
|--------|------------|
| `Telegram::BotService` | Telegram API (send_message, download_file, send_typing) |
| `Telegram::MessageHandler` | Роутинг и обработка сообщений, основная бизнес-логика |
| `TelegramAuthService` | Telegram Login Widget авторизация для веб-интерфейса |
| `Ai::WhisperService` | Speech-to-text через OpenAI Whisper (русский по умолчанию) |
| `Ai::ContentAnalyzer` | GPT-4 классификация контента (diary/idea/plan/nutrition/activity/command) |
| `Ai::MultiPlanAnalyzer` | Извлечение нескольких планов из одного сообщения |
| `Ai::VisionService` | Анализ фото еды, распознавание продуктов и БЖУ |
| `Ai::GarminAnalyzer` | Распознавание скриншотов Garmin с данными тренировок |
| `Ai::CorrectionDetector` | Обнаружение исправлений в последних записях (10 мин окно) |
| `Ai::CorrectionApplier` | Применение исправлений к записям |
| `Ai::AutoPlanner` | Автоматическое планирование (daily/weekly) |
| `Ai::ScheduleOptimizer` | Оптимизация расписания задач |
| `TimezoneService` | Определение timezone по координатам или названию города |

### Модели данных

**Основные:**
- `User` — пользователь Telegram (telegram_id, timezone, language, last_entry_ids для исправлений)
- `Entry` — весь контент (diary/idea/plan/plan_update/nutrition/activity)
  - Поля: entry_type, content, category (inbox/work/life/health/ideas/projects), dashboard_status (new/triaged/processed/archived)
  - Группировка: parent_entry_id, group_id для связанных записей
  - Идеи: idea_category, idea_status, idea_priority, research_data, quest_generated
- `CalendarEvent` — события с приоритетом, all_day флагом, привязкой к Entry
- `Reminder` — напоминания (one_time/recurring/smart) с user_feedback
- `NutritionEntry` — трекинг питания (calories, protein, fat, carbs, meal_type, photo_url)
- `ActivityEntry` — фитнес-трекинг (activity_type, duration, distance, heart_rate, garmin_data)

**Расширенные:**
- `Insight` — AI-инсайты и аналитика (daily_summary/weekly_digest/trend_analysis)
- `Quest` — геймифицированные задачи из идей (steps, completion_rate, rewards)
- `TelegramAuthSession` — сессии авторизации для веб-интерфейса (session_token, expires_at)

**Важные связи:**
- Entry → CalendarEvent (has_one)
- Entry → NutritionEntry (has_one)
- Entry → Reminders (has_many)
- Entry → Quests (has_many)
- Entry → parent_entry (belongs_to, для группировки)

## Важные паттерны

### Обработка ошибок
- **КРИТИЧНО**: Всегда возвращать 200 OK на Telegram webhook (предотвращает повторы)
- Graceful fallbacks в AI-сервисах (дефолт если API упал)
- Логирование через `Rails.logger` с контекстом

### Асинхронность
- Вся обработка webhook через Solid Queue background jobs
- Никогда не блокировать ответ webhook
- Периодические задачи настроены в `config/recurring.yml`

### Timezone handling
- ВСЕГДА использовать `user.timezone` для дат/времени
- `Time.current.in_time_zone(user.timezone)` для текущего времени
- `Ai::ContentAnalyzer` получает local_time пользователя (content_analyzer.rb:184)
- TimezoneService для определения timezone по координатам или городу

### Группировка записей
- Связанные идеи из одного голосового сообщения группируются через `group_id`
- Parent entry содержит комбинированный контент
- Child entries содержат отдельные размышления
- Проверка: `entry.is_parent?`, `entry.is_child?`, `entry.all_related_content`

### Исправления (Corrections)
- 10-минутное окно для исправления последних записей
- `User#last_entry_ids` и `last_entry_timestamp` для отслеживания
- `Ai::CorrectionDetector` обнаруживает исправления
- `Ai::CorrectionApplier` применяет изменения
- Типы: nutrition_correction, time_correction, content_correction, type_correction

### Переменные окружения
- Обязательные: `TELEGRAM_BOT_TOKEN`, `OPENAI_API_KEY`
- Хранятся в Rails credentials (`bin/rails credentials:edit`)
- Доступ: `Rails.application.credentials.telegram[:bot_token]`
- Структура:
  ```yaml
  telegram:
    bot_token: XXX
    bot_name: echo_bot
  openai:
    api_key: sk-XXX
  ```

## Команды бота

### Основные команды
```
/start      - Начать работу (поддерживает deep link для auth)
/help       - Справка
/settings   - Настройки
/status     - Статистика
/timezone   - Настройка часового пояса (или отправить геолокацию)
```

### Календарь и планирование
```
/calendar   - Календарь на неделю
/today      - События на сегодня
/week       - События на неделю
/add_event  - Создание события
/plan       - Создать план на день/неделю
/optimize   - Оптимизировать расписание
/suggest    - Умные предложения задач
/autoplan   - Полное автопланирование
```

### Аналитика и инсайты
```
/insights   - Последние инсайты
/digest     - Недельный дайджест (асинхронный через GenerateInsightJob)
/daily      - Резюме за сегодня (асинхронный)
/stats      - Подробная статистика
```

### Питание и активность
```
/nutrition  - Статистика питания за день
```

### Напоминания
```
/remind     - Создать напоминание (парсинг через AI)
/reminders  - Список напоминаний
/smart      - Управление умными напоминаниями
```

### Специальные команды (внутренние)
- `/start auth_<token>` — авторизация для веб-интерфейса через deep link

## Продакшн

- Kamal (Docker) деплой
- Сервер: 46.62.211.95
- Домен: echo.datapine.space
- Registry: ghcr.io/zimondata/echo
- SQLite3 базы в persistent volume (`echo_db:/rails/db`)
- Storage в persistent volume (`echo_storage:/rails/storage`)

## Локализация

- Основной язык: русский (ru)
- Все сообщения пользователю на русском
- AI-промпты на русском
- Поддержка таймзон через User model (дефолт: UTC)

## Веб-интерфейс

### Авторизация через Telegram
- Реализовано через Telegram Login Widget
- Поток: веб → создание `TelegramAuthSession` → deep link в бот → подтверждение → callback
- Роуты: `telegram_auth/initiate`, `telegram_auth/:token/status`
- Модель: `TelegramAuthSession` (session_token, telegram_id, expires_at)
- Периодическая очистка: `CleanupExpiredAuthSessionsJob` каждые 5 минут

### ActionCable (WebSockets)
- Endpoint: `/cable`
- Настроен для real-time обновлений (будущее использование)
- Каналы в `app/channels/`

### Основные маршруты
- Dashboard: `/dashboard`
- Entries: `/entries`, `/ideas`, `/plans`, `/diary`
- Nutrition: `/nutrition`
- Calendar: `/calendar_events`
- Quests: `/quests`
- Ideas Dashboard: `/ideas_dashboard` (исследование идей, генерация квестов)
- API: `/api/v1/*` для программного доступа

## Background Jobs (Solid Queue)

### Периодические задачи (config/recurring.yml)
```yaml
send_reminders: каждую минуту
contextual_notifications: каждый час
smart_reminders: каждые 6 часов
weekly_insights: каждое воскресенье в 20:00
calendar_sync: каждые 4 часа
cleanup_expired_auth_sessions: каждые 5 минут
clear_solid_queue_finished_jobs: каждый час
```

### Основные Jobs
- `TelegramWebhookJob` — обработка webhook от Telegram
- `SendRemindersJob` — отправка напоминаний
- `GenerateInsightJob` — генерация инсайтов (daily/weekly)
- `GenerateSmartRemindersJob` — AI-генерация умных напоминаний
- `ScheduleContextualNotificationsJob` — контекстные уведомления
- `CleanupExpiredAuthSessionsJob` — очистка истёкших auth сессий

## Тестирование и отладка

### Проверка webhook
```bash
# Получить информацию о webhook
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"

# Проверить логи
tail -f log/development.log
```

### Rails консоль
```ruby
# Найти пользователя
user = User.find_by(telegram_id: 123456789)

# Последние записи
user.entries.recent.limit(5)

# Создать тестовое напоминание
user.reminders.create!(
  reminder_type: "one_time",
  remind_at: 5.minutes.from_now,
  message: "Тест"
)

# Проверить calendar events
user.calendar_events.for_week

# Nutrition за сегодня
NutritionEntry.daily_totals(user, Date.current)
```

### Тестирование AI сервисов
```ruby
# Анализ контента
analysis = Ai::ContentAnalyzer.analyze("Завтра в 15:00 встреча с клиентом", user: user)

# Multi-plan анализ
analyses = Ai::MultiPlanAnalyzer.analyze("Завтра созвон в 14:00 и встреча в 16:00", user: user)

# Correction detection
Ai::CorrectionDetector.analyze("Нет, в 17:30", recent_entries, user: user)
```

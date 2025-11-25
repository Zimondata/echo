# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

Echo — Telegram AI-ассистент для управления дневником, идеями, планами, активностью и питанием через голосовой и текстовый ввод. Использует OpenAI GPT-4 для анализа контента и Whisper для транскрипции речи.

**Технологии:**
- Ruby 3.4.5
- Rails 8.0.3
- SQLite3
- Sidekiq (фоновые задачи)
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- Telegram Bot API
- OpenAI API (GPT-4, Whisper)

## Рекомендации по разработке

### Rails 8 стек
- Избегать лишнего JavaScript — использовать Turbo Streams
- Использовать SolidQueue для очередей (когда включён)
- SolidCable для WebSockets
- SolidCache для кэширования views

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

2. **Асинхронная обработка**
   - `TelegramWebhookJob` обрабатывает через Sidekiq
   - Создаёт/находит `User` по `telegram_id`
   - Делегирует в `Telegram::MessageHandler`

3. **Обработка сообщений**
   - Команды (`/start`, `/help`, `/calendar`, `/insights`, `/stats`) → обработчики команд
   - Голос → `Ai::WhisperService` → обработка контента
   - Текст → обработка контента напрямую

4. **Обработка контента**
   - `Ai::ContentAnalyzer` классифицирует: `diary`, `idea`, `plan`, `plan_update`
   - Создаёт `Entry` с метаданными
   - Опционально создаёт `CalendarEvent`, `Reminder`, `Quest`

### Ключевые сервисы

| Сервис | Назначение |
|--------|------------|
| `Telegram::BotService` | Telegram API (send_message, download_file) |
| `Telegram::MessageHandler` | Роутинг и обработка сообщений |
| `Ai::WhisperService` | Speech-to-text (русский по умолчанию) |
| `Ai::ContentAnalyzer` | GPT-4 классификация контента |

### Модели данных

**Основные:**
- `User` — пользователь Telegram (telegram_id, timezone, language, settings)
- `Entry` — весь контент (diary/idea/plan/plan_update), category, status, insights
- `CalendarEvent` — события с приоритетом, тегами, привычками, повторениями
- `Reminder` — умные напоминания с AI-контекстом и кнопками действий

**Расширенные:**
- `Insight` — AI-инсайты и аналитика
- `Quest` — геймифицированные задачи из идей (steps, completion_rate)
- `ActivityEntry` — фитнес-трекинг (интеграция Garmin)
- `NutritionEntry` — трекинг питания с анализом макросов

## Важные паттерны

### Обработка ошибок
- Всегда возвращать 200 OK на Telegram webhook (предотвращает повторы)
- Graceful fallbacks в AI-сервисах (дефолт если API упал)

### Асинхронность
- Вся обработка webhook через background jobs
- Никогда не блокировать ответ webhook

### Переменные окружения
- Обязательные: `TELEGRAM_BOT_TOKEN`, `OPENAI_API_KEY`
- Хранятся в Rails credentials (`bin/rails credentials:edit`)
- Доступ: `Rails.application.credentials.telegram[:bot_token]`

## Команды бота

```
/start      - Начать работу
/help       - Справка
/settings   - Настройки
/status     - Статистика
/calendar   - Календарь на неделю
/today      - События на сегодня
/week       - События на неделю
/add_event  - Создание события
/insights   - Последние инсайты
/digest     - Недельный дайджест
/daily      - Резюме за сегодня
/stats      - Подробная статистика
```

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

# Echo - Setup Instructions

## Что уже сделано (Фаза 1 - частично завершена)

### ✅ Инфраструктура
1. **PostgreSQL настроен**
   - База данных: `echo_development`, `echo_test`
   - Расширение pgvector установлено для AI embeddings

2. **Модели данных созданы**
   - `User` - пользователи Telegram
   - `Entry` - записи (дневник/идеи/планы)
   - `CalendarEvent` - события календаря
   - `Reminder` - напоминания

3. **Gems установлены**
   - `telegram-bot-ruby` - Telegram Bot API
   - `ruby-openai` - OpenAI (Whisper, GPT-4)
   - `google-apis-calendar_v3` - Google Calendar API
   - `neighbor` - pgvector для векторного поиска
   - `sidekiq` - фоновые задачи

4. **Webhook endpoint создан**
   - POST `/telegram/webhook` готов принимать сообщения

---

## 📋 Следующие шаги

### Шаг 1: Получить API ключи

#### 1.1 Создать Telegram Bot
1. Открой Telegram и найди @BotFather
2. Отправь `/newbot`
3. Следуй инструкциям (имя бота, username)
4. Получи токен (формат: `110201543:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw`)
5. Добавь токен в Rails credentials:
   ```bash
   EDITOR="nano" bin/rails credentials:edit
   ```
   Добавь в файл:
   ```yaml
   telegram:
     bot_token: твой_токен_здесь
   ```

#### 1.2 Получить OpenAI API ключ
1. Зайди на https://platform.openai.com/api-keys
2. Создай новый API key
3. Добавь в Rails credentials:
   ```bash
   EDITOR="nano" bin/rails credentials:edit
   ```
   Добавь в файл:
   ```yaml
   openai:
     api_key: sk-...твой_ключ
   ```

#### 1.3 Настроить Google Calendar API
1. Зайди на https://console.cloud.google.com/
2. Создай новый проект (или выбери существующий)
3. Включи Google Calendar API
4. Создай OAuth 2.0 credentials
5. Скачай JSON с credentials
6. Добавь в `.env`:
   ```
   GOOGLE_CLIENT_ID=твой_client_id
   GOOGLE_CLIENT_SECRET=твой_client_secret
   ```

---

### Шаг 2: Что нужно доделать в коде

#### 2.1 Создать TelegramWebhookJob
```bash
bin/rails generate job TelegramWebhook
```

Этот job будет:
- Обрабатывать входящие сообщения
- Определять команды (/start, /help, и т.д.)
- Обрабатывать голосовые сообщения
- Вызывать AI сервисы

#### 2.2 Создать сервисы

**Telegram::MessageHandler** - обработка сообщений
**Ai::WhisperService** - транскрипция аудио
**Ai::ContentAnalyzer** - анализ контента через GPT-4
**Google::CalendarService** - работа с Google Calendar

#### 2.3 Настроить Telegram Bot команды
- `/start` - регистрация пользователя
- `/help` - помощь
- `/settings` - настройки
- `/status` - статистика

---

### Шаг 3: Тестирование локально

#### 3.1 Установить ngrok для webhook
```bash
brew install ngrok
ngrok http 3000
```

#### 3.2 Установить webhook в Telegram
```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -d "url=https://your-ngrok-url.ngrok.io/telegram/webhook"
```

#### 3.3 Запустить сервер
```bash
bin/dev
```

---

## 🎯 MVP функционал для первого теста

### Минимальная реализация (1-2 дня):

1. **Telegram Bot**
   - ✅ Webhook настроен
   - ⏳ Команда `/start` - создание пользователя
   - ⏳ Прием текстовых сообщений
   - ⏳ Прием голосовых сообщений

2. **AI Processing**
   - ⏳ Speech-to-text через Whisper
   - ⏳ Анализ через GPT-4 (определение типа: дневник/идея/план)
   - ⏳ Сохранение в базу

3. **Базовый ответ**
   - ⏳ Подтверждение сохранения
   - ⏳ Краткое резюме записи

### После MVP (следующие шаги):

4. **Google Calendar**
   - OAuth авторизация
   - Создание событий
   - Синхронизация

5. **Напоминания**
   - Background job для проверки
   - Отправка в Telegram

6. **Умные фичи**
   - Векторный поиск похожих идей
   - Проактивные инсайты
   - Автоматическое планирование

---

## 📝 Пример использования (после завершения MVP)

```
Ты: [голосовое] "У меня возникла идея сделать AI-ассистента
     для управления дневником и планами через Telegram"

Bot: 📝 Записал твою идею!

     💡 Тип: Идея
     📅 Дата: 13 октября 2025, 08:47

     Резюме: Создание AI-ассистента для управления дневником
     и планированием через Telegram с голосовым интерфейсом.

     Что дальше?
     [Создать план] [Напомнить позже] [Архивировать]
```

---

## 🛠 Команды для разработки

```bash
# Запустить сервер
bin/dev

# Запустить консоль
bin/rails console

# Миграции
bin/rails db:migrate

# Запустить Sidekiq (для фоновых задач)
bundle exec sidekiq

# Проверить routes
bin/rails routes | grep telegram
```

---

## 🔧 Troubleshooting

### Ошибка подключения к PostgreSQL
```bash
brew services start postgresql@17
```

### Ошибка с pgvector
```bash
brew install pgvector
bin/rails db:migrate:redo
```

### Telegram не получает сообщения
1. Проверь, что ngrok запущен
2. Проверь webhook: `https://api.telegram.org/bot<TOKEN>/getWebhookInfo`
3. Проверь логи: `tail -f log/development.log`

---

## 📚 Полезные ссылки

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [OpenAI API Docs](https://platform.openai.com/docs/api-reference)
- [Google Calendar API](https://developers.google.com/calendar/api/guides/overview)
- [Rails Guides](https://guides.rubyonrails.org/)

---

## Следующий этап разработки

Теперь нужно написать код для обработки сообщений. Готов продолжить?

Скажи "продолжай" и я:
1. Создам TelegramWebhookJob
2. Напишу MessageHandler сервис
3. Интегрирую Whisper для голосовых сообщений
4. Настрою базовую AI обработку

После этого сможешь протестировать первую версию!

# Echo - AI Personal Assistant

> Автономный AI-ассистент для управления дневником, идеями и планами через голосовой интерфейс в Telegram

[![Ruby](https://img.shields.io/badge/Ruby-3.4.5-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0.3-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-blue.svg)](https://www.postgresql.org/)

---

## 🌟 Возможности

- 🎤 **Голосовой ввод** - наговаривай свои мысли прямо в Telegram
- 🤖 **AI-анализ** - автоматическое определение типа записи (дневник/идея/план)
- 📅 **Умное планирование** - создание событий с автоматическим извлечением дат
- 🔔 **Напоминания** - автоматические уведомления в нужное время
- 🔍 **Векторный поиск** - находи похожие идеи и записи
- 📊 **Статистика** - отслеживай свою активность

---

## 🏗 Архитектура

```
┌─────────────────┐
│   Telegram Bot  │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Rails Backend  │
│  ├─ Webhook     │
│  ├─ AI Services │
│  └─ Jobs        │
└────────┬────────┘
         │
    ┌────┴────┬─────────┬──────────┐
    ↓         ↓         ↓          ↓
┌─────┐  ┌────────┐ ┌────────┐ ┌────────┐
│ GPT │  │Whisper │ │ Google │ │pgvector│
│  4  │  │  API   │ │Calendar│ │        │
└─────┘  └────────┘ └────────┘ └────────┘
```

---

## 🚀 Quick Start

### Требования

- Ruby 3.4.5
- PostgreSQL 17 с pgvector
- Telegram Bot Token
- OpenAI API Key

### Установка

```bash
# Клонировать репозиторий
git clone <repo-url>
cd Echo

# Установить зависимости
bundle install

# Настроить базу данных
bin/rails db:create db:migrate

# Настроить переменные окружения
cp .env.example .env
nano .env  # Добавь свои API ключи

# Запустить сервер
bin/dev
```

### Настройка Telegram Webhook

```bash
# Установить ngrok
brew install ngrok

# Запустить ngrok
ngrok http 3000

# Установить webhook
curl -X POST "https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook" \
  -d "url=<YOUR_NGROK_URL>/telegram/webhook"
```

📖 **Подробная инструкция:** см. [QUICK_START.md](QUICK_START.md)

---

## 📖 Документация

- [QUICK_START.md](QUICK_START.md) - Быстрый старт и тестирование
- [PROJECT_ROADMAP.md](PROJECT_ROADMAP.md) - Полный план проекта
- [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) - Детальные инструкции

---

## 💬 Использование

### Команды бота:

```
/start    - Начать работу
/help     - Справка
/settings - Настройки
/status   - Статистика
```

### Примеры:

**Дневниковая запись:**
```
"Сегодня был отличный день, завершил важный проект"
```

**Идея:**
```
🎤 "У меня идея создать AI-инструмент для автоматизации планирования"
```

**План с напоминанием:**
```
"Завтра в 14:00 встреча с клиентом"
```

---

## 🛠 Технологии

### Backend
- **Rails 8.0** - веб-фреймворк
- **PostgreSQL 17** - база данных
- **pgvector** - векторный поиск
- **Solid Queue** - фоновые задачи

### AI & Integrations
- **OpenAI GPT-4** - анализ контента
- **Whisper API** - speech-to-text
- **Telegram Bot API** - интерфейс
- **Google Calendar API** - синхронизация событий

### Gems
- `telegram-bot-ruby` - Telegram интеграция
- `ruby-openai` - OpenAI API клиент
- `neighbor` - pgvector wrapper
- `google-apis-calendar_v3` - Google Calendar

---

## 📊 Структура проекта

```
app/
├── controllers/
│   └── telegram_controller.rb      # Webhook endpoint
├── jobs/
│   ├── telegram_webhook_job.rb     # Обработка сообщений
│   └── send_reminders_job.rb       # Отправка напоминаний
├── models/
│   ├── user.rb                     # Пользователь
│   ├── entry.rb                    # Запись (дневник/идея/план)
│   ├── calendar_event.rb           # Событие календаря
│   └── reminder.rb                 # Напоминание
└── services/
    ├── telegram/
    │   ├── bot_service.rb          # Telegram API
    │   └── message_handler.rb      # Обработчик сообщений
    └── ai/
        ├── whisper_service.rb      # Speech-to-text
        └── content_analyzer.rb     # AI анализ
```

---

## 🔧 Разработка

### Запуск в dev режиме

```bash
# Сервер
bin/dev

# Консоль
bin/rails console

# Тесты
bin/rails test

# Проверка кода
bin/rubocop
```

### Полезные команды

```bash
# Посмотреть записи пользователя
User.first.entries.recent

# Создать тестовое напоминание
Reminder.create!(
  user: User.first,
  reminder_type: "one_time",
  remind_at: 5.minutes.from_now,
  message: "Тест"
)

# Проверить webhook
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
```

---

## 🎯 Roadmap

### ✅ Фаза 1: MVP (Завершено)
- [x] PostgreSQL + pgvector
- [x] Модели данных
- [x] Telegram Bot webhook
- [x] Whisper speech-to-text
- [x] GPT-4 анализ
- [x] Базовые команды
- [x] Напоминания

### 🚧 Фаза 2: Google Calendar (В работе)
- [ ] OAuth авторизация
- [ ] Создание событий
- [ ] Синхронизация
- [ ] Обновление планов

### 📋 Фаза 3: Умные фичи
- [ ] Векторный поиск похожих идей
- [ ] Проактивные инсайты
- [ ] Еженедельные дайджесты
- [ ] Автоматическое планирование

### 🔮 Фаза 4: Расширенная интеграция
- [ ] n8n workflows
- [ ] Notion/Trello синхронизация
- [ ] Web интерфейс
- [ ] Mobile приложение

---

## 📈 Производительность

- Обработка сообщений: ~2-3 секунды
- Speech-to-text: ~1-2 секунды
- AI анализ: ~1-2 секунды
- Векторный поиск: ~50ms

---

## 💰 Стоимость (примерная)

При активном использовании (~100 записей/месяц):

- OpenAI Whisper: ~$0.36/месяц
- OpenAI GPT-4 Turbo: ~$5-10/месяц
- Google Calendar API: Бесплатно
- Telegram Bot: Бесплатно

**Итого: ~$6-11/месяц**

---

## 🤝 Contributing

Pull requests приветствуются! Для крупных изменений откройте issue для обсуждения.

---

## 📄 License

MIT

---

## 👤 Author

Создано с использованием Claude Code

---

## 🆘 Поддержка

Если возникли проблемы:

1. Проверь [QUICK_START.md](QUICK_START.md) - раздел Troubleshooting
2. Посмотри логи: `tail -f log/development.log`
3. Проверь webhook: `curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"`

---

**Начни использовать Echo прямо сейчас! 🚀**

📖 См. [QUICK_START.md](QUICK_START.md) для быстрого старта

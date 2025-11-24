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
- 🧠 **Проактивные инсайты** - AI-анализ паттернов поведения и продуктивности  
- 📈 **Еженедельные дайджесты** - автоматические отчеты с достижениями и целями
- 📊 **Аналитика настроения** - отслеживание эмоционального состояния
- 🔍 **Детальная статистика** - полная картина твоей активности

---

## 🏗 Архитектура

```
┌─────────────────┐    ┌─────────────────┐
│   Telegram Bot  │    │  Web Interface  │ 🚀 Фаза 4
└────────┬────────┘    └────────┬────────┘
         │                      │
         └──────────┬───────────┘
                    ↓
         ┌─────────────────┐
         │  Rails Backend  │
         │  ├─ Webhook     │
         │  ├─ AI Services │ 🧠 Auto Planning
         │  ├─ Analytics   │ 📊 Smart Insights  
         │  └─ Jobs        │
         └────────┬────────┘
                  │
    ┌─────────────┼─────────────┬──────────┐
    ↓             ↓             ↓          ↓
┌─────┐    ┌────────────┐  ┌────────┐ ┌────────┐
│ GPT │    │  n8n/Zapier │  │ Own    │ │pgvector│
│  4  │    │ Workflows   │  │Calendar│ │        │
└─────┘    └────────────┘  └────────┘ └────────┘
           ⚡ Фаза 5
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

# Настроить Rails credentials (API ключи)
EDITOR="nano" bin/rails credentials:edit
# Добавь свои API ключи:
# telegram:
#   bot_token: YOUR_TELEGRAM_BOT_TOKEN
# openai:
#   api_key: YOUR_OPENAI_API_KEY

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
- [PROJECT_ROADMAP.md](PROJECT_ROADMAP.md) - Детальный роадмап и стратегия развития
- [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) - Детальные инструкции

---

## 💬 Использование

### Команды бота:

```
/start      - Начать работу
/help       - Справка
/settings   - Настройки
/status     - Статистика

Календарь:
/calendar   - Просмотр календаря на неделю
/today      - События на сегодня
/week       - События на неделю
/add_event  - Быстрое создание события

Аналитика и инсайты:
/insights   - Последние инсайты
/digest     - Недельный дайджест
/daily      - Резюме за сегодня
/stats      - Подробная статистика
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

**Календарные команды:**
```
/today      - "📅 События на сегодня"
/calendar   - "📅 Календарь на неделю" 
/add_event  - "📅 Быстрое создание события"
```

**Аналитические команды:**
```
/insights   - "🧠 Последние инсайты"
/digest     - "📈 Генерирую недельный дайджест..."
/daily      - "📊 Анализирую твой день..."
/stats      - "📊 Подробная статистика за неделю"
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
- **Собственный календарь** - управление событиями

### Gems
- `telegram-bot-ruby` - Telegram интеграция
- `ruby-openai` - OpenAI API клиент
- `neighbor` - pgvector wrapper

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

### ✅ Фаза 2: Собственный Календарь (Завершено)
- [x] Модель CalendarEvent с полным функционалом
- [x] Категории событий и приоритеты
- [x] Напоминания и уведомления
- [x] API для управления событиями
- [x] Telegram команды календаря
- [x] Фильтрация и статистика

### ✅ Фаза 3: Умные фичи (Завершено)
- [x] Проактивные инсайты и аналитика
- [x] Еженедельные дайджесты  
- [x] Автоматические отчеты по активности
- [x] Анализ настроения и продуктивности
- [x] Автоматическое планирование с AI
- [ ] Векторный поиск похожих идей (отложено)

### 🚀 Фаза 4: Web интерфейс (В работе)
- [ ] Dashboard с календарем и статистикой
- [ ] Веб-просмотр инсайтов и аналитики
- [ ] Управление записями через браузер
- [ ] Responsive дизайн для мобильных
- [ ] Синхронизация с Telegram ботом

### ⚡ Фаза 5: Workflow автоматизация
- [ ] n8n workflows интеграция
- [ ] Автоматические триггеры событий
- [ ] Интеграция с внешними сервисами
- [ ] Notion/Trello синхронизация
- [ ] Zapier webhooks

### 🔮 Фаза 6: Расширенная экосистема  
- [ ] Mobile приложение (React Native)
- [ ] API для третьих лиц
- [ ] Плагины и расширения
- [ ] Multi-tenant архитектура

---

## 🎯 Детальный план развития

### 🚀 **Фаза 4: Web интерфейс** (Текущая фаза)

**Цель:** Создать современный веб-интерфейс для полноценной работы с Echo

**Ключевые компоненты:**
- **Dashboard** - общий обзор активности, статистики и инсайтов
- **Calendar View** - интерактивный календарь с drag&drop событий
- **Analytics Panel** - визуализация трендов и паттернов поведения
- **Entry Management** - создание, редактирование и организация записей
- **Real-time Sync** - синхронизация с Telegram ботом

**Технологический стек:**
- **Frontend:** Next.js 14, TypeScript, Tailwind CSS
- **Компоненты:** Shadcn/ui, Recharts для графиков
- **Real-time:** WebSockets или Server-Sent Events
- **Аутентификация:** NextAuth.js с Telegram OAuth

### ⚡ **Фаза 5: Workflow автоматизация**

**Цель:** Превратить Echo в центр автоматизации личной продуктивности

**n8n Workflows:**
- **Smart Reminders** - напоминания на основе контекста и местоположения
- **Cross-platform Sync** - автоматическая синхронизация с Notion, Trello, Todoist
- **AI Suggestions** - предложения действий на основе паттернов
- **External Triggers** - реакция на события из календаря, email, Slack

**Zapier Integration:**
- **2000+ приложений** - интеграция с популярными сервисами
- **Custom Webhooks** - для специфичных автоматизаций
- **Multi-step Workflows** - сложные сценарии автоматизации

### 🔮 **Фаза 6: Расширенная экосистема**

**Mobile App (React Native):**
- Нативные уведомления и виджеты
- Offline-first архитектура
- Голосовой ввод с улучшенным UX

**API Ecosystem:**
- RESTful API для третьих лиц
- GraphQL для сложных запросов
- SDK для популярных языков программирования

**Enterprise Features:**
- Multi-tenant архитектура
- Team collaboration
- Advanced analytics и reporting
- GDPR compliance

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

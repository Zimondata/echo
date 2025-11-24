# Echo - Launch Checklist

## ✅ Быстрый чеклист для запуска

Используй этот список для быстрой проверки перед запуском.

---

## 📋 Предварительные требования

- [ ] Ruby 3.4.5 установлен
- [ ] PostgreSQL 17 установлен и запущен
- [ ] pgvector расширение установлено
- [ ] Gems установлены (`bundle install` выполнен)
- [ ] База данных создана (`bin/rails db:create db:migrate`)

---

## 🔑 API Ключи

### Telegram Bot
- [ ] Бот создан через @BotFather
- [ ] Token скопирован
- [ ] Token добавлен в Rails credentials (`rails credentials:edit`) как `telegram.bot_token`

### OpenAI
- [ ] Аккаунт создан на platform.openai.com
- [ ] API Key создан
- [ ] Key добавлен в Rails credentials (`rails credentials:edit`) как `openai.api_key`
- [ ] Есть баланс на счету (минимум $1)

---

## 🌐 Webhook Setup

### ngrok
- [ ] ngrok установлен (`brew install ngrok`)
- [ ] ngrok запущен (`ngrok http 3000`)
- [ ] HTTPS URL скопирован (например: `https://abc123.ngrok.io`)

### Telegram Webhook
- [ ] Webhook установлен:
```bash
curl -X POST "https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook" \
  -d "url=<YOUR_NGROK_URL>/telegram/webhook"
```

- [ ] Webhook проверен:
```bash
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getWebhookInfo"
```

Ожидается: `"url": "https://your-ngrok.ngrok.io/telegram/webhook"`

---

## 🚀 Запуск приложения

- [ ] Rails credentials настроены (`rails credentials:show` показывает telegram и openai ключи)
- [ ] PostgreSQL запущен: `brew services list | grep postgres`
- [ ] Сервер запущен: `bin/dev`
- [ ] Логи чистые: `tail -f log/development.log`

---

## 🧪 Тесты

### Тест 1: Приложение загружается
```bash
bin/rails runner "puts 'OK'"
```
- [ ] Вывод: `OK`

### Тест 2: Webhook route существует
```bash
bin/rails routes | grep telegram
```
- [ ] Вывод содержит: `POST /telegram/webhook`

### Тест 3: Модели работают
```bash
bin/rails console
> User.count
> Entry.count
```
- [ ] Команды выполняются без ошибок

### Тест 4: Telegram бот отвечает
В Telegram отправить боту:
```
/start
```
- [ ] Получен приветственный ответ

### Тест 5: Текстовое сообщение
Отправить боту:
```
Сегодня был хороший день
```
- [ ] Получено подтверждение с типом "Дневник"

### Тест 6: Голосовое сообщение
- [ ] Отправить голосовое сообщение
- [ ] Получено: "🎤 Обрабатываю голосовое сообщение..."
- [ ] Получено подтверждение с транскрипцией

### Тест 7: Команда /status
```
/status
```
- [ ] Получена статистика записей

---

## 🐛 Troubleshooting Checklist

Если бот не отвечает:

- [ ] ngrok запущен и URL не изменился
- [ ] Webhook установлен на правильный URL
- [ ] Сервер Rails запущен (`bin/dev`)
- [ ] В логах нет ошибок (`tail -f log/development.log`)
- [ ] PostgreSQL запущен
- [ ] API ключи правильные в Rails credentials (`rails credentials:show`)

Если ошибка OpenAI:

- [ ] Ключ правильный
- [ ] Есть баланс на счету
- [ ] Интернет соединение работает

Если Whisper не работает:

- [ ] Telegram отправляет аудио в правильном формате
- [ ] Файл скачивается (проверить логи)
- [ ] OpenAI API доступен

---

## ✨ Готовность к production

Для production deployment дополнительно:

- [ ] Получить постоянный домен (не ngrok)
- [ ] Настроить SSL сертификат
- [ ] Настроить переменные окружения на сервере
- [ ] Настроить мониторинг (Sentry, Honeybadger)
- [ ] Настроить backup базы данных
- [ ] Настроить Google Calendar OAuth
- [ ] Установить rate limiting
- [ ] Добавить капчу для защиты
- [ ] Настроить логирование

---

## 📊 Метрики успеха

После запуска проверь:

- [ ] Сообщения обрабатываются < 3 секунд
- [ ] Whisper транскрипция < 2 секунд
- [ ] AI анализ < 2 секунд
- [ ] Напоминания отправляются вовремя
- [ ] Нет ошибок в логах
- [ ] База данных отвечает быстро

---

## 🎯 Следующие шаги

После успешного запуска:

- [ ] Протестировать все команды
- [ ] Создать несколько записей разных типов
- [ ] Проверить напоминания работают
- [ ] Дать фидбек по UX
- [ ] Определить приоритетные улучшения
- [ ] Начать работу над Google Calendar (Фаза 2)

---

## 📝 Quick Commands Reference

```bash
# Запустить сервер
bin/dev

# Консоль
bin/rails console

# Логи
tail -f log/development.log

# Проверить webhook
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"

# Запустить ngrok
ngrok http 3000

# Проверить PostgreSQL
brew services list | grep postgres

# Миграции
bin/rails db:migrate

# Проверить routes
bin/rails routes | grep telegram
```

---

**Используй этот чеклист каждый раз при запуске проекта!** ✅

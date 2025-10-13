#!/bin/bash

# Echo - Quick Start Script
# Этот скрипт поможет быстро запустить проект

echo "🚀 Echo - AI Personal Assistant"
echo "================================"
echo ""

# Проверка PostgreSQL
echo "📊 Проверка PostgreSQL..."
if brew services list | grep -q "postgresql@17.*started"; then
  echo "✅ PostgreSQL запущен"
else
  echo "❌ PostgreSQL не запущен"
  echo "   Запускаю PostgreSQL..."
  brew services start postgresql@17
  sleep 2
fi

# Проверка API ключей
echo ""
echo "🔑 Проверка API ключей..."
if grep -q "your_telegram_bot_token_here" .env || grep -q "your_openai_api_key_here" .env; then
  echo "❌ API ключи не настроены в .env файле"
  echo "   Отредактируй файл .env и добавь реальные ключи"
  exit 1
else
  echo "✅ API ключи настроены"
fi

# Проверка зависимостей
echo ""
echo "📦 Проверка зависимостей..."
if ! bundle check > /dev/null 2>&1; then
  echo "❌ Gems не установлены"
  echo "   Запускаю bundle install..."
  bundle install
else
  echo "✅ Все gems установлены"
fi

# Проверка базы данных
echo ""
echo "🗄️  Проверка базы данных..."
if bin/rails db:version > /dev/null 2>&1; then
  echo "✅ База данных готова"
else
  echo "❌ База данных не готова"
  echo "   Создаю базу и запускаю миграции..."
  bin/rails db:create db:migrate
fi

echo ""
echo "================================"
echo "✨ Всё готово к запуску!"
echo ""
echo "Теперь выполни следующие команды в РАЗНЫХ терминалах:"
echo ""
echo "1️⃣  Терминал 1 - Запуск Rails сервера:"
echo "   bin/dev"
echo ""
echo "2️⃣  Терминал 2 - Запуск ngrok:"
echo "   ngrok http 3000"
echo ""
echo "3️⃣  После запуска ngrok, скопируй HTTPS URL (например: https://abc123.ngrok.io)"
echo "   и установи webhook:"
echo ""
echo "   curl -X POST \"https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook\" \\"
echo "     -d \"url=<YOUR_NGROK_URL>/telegram/webhook\""
echo ""
echo "Или используй готовый скрипт: ./set_webhook.sh <NGROK_URL>"
echo ""

#!/bin/bash

# Echo - Set Telegram Webhook Script

# Получить Telegram Bot Token из .env
BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN .env | cut -d '=' -f2)

if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "your_telegram_bot_token_here" ]; then
  echo "❌ TELEGRAM_BOT_TOKEN не найден в .env файле"
  exit 1
fi

# Проверить аргумент (ngrok URL)
if [ -z "$1" ]; then
  echo "❌ Использование: ./set_webhook.sh <NGROK_URL>"
  echo ""
  echo "Пример:"
  echo "  ./set_webhook.sh https://abc123.ngrok.io"
  exit 1
fi

NGROK_URL=$1
WEBHOOK_URL="${NGROK_URL}/telegram/webhook"

echo "🔗 Устанавливаю webhook..."
echo "   Bot Token: ${BOT_TOKEN:0:20}..."
echo "   Webhook URL: $WEBHOOK_URL"
echo ""

# Установить webhook
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -d "url=${WEBHOOK_URL}")

echo "Ответ от Telegram:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Проверить webhook
echo "🔍 Проверяю webhook..."
WEBHOOK_INFO=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo")

echo "$WEBHOOK_INFO" | python3 -m json.tool 2>/dev/null || echo "$WEBHOOK_INFO"
echo ""

# Проверить успешность
if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "✅ Webhook успешно установлен!"
  echo ""
  echo "🎉 Теперь отправь боту /start в Telegram!"
else
  echo "❌ Ошибка при установке webhook"
  echo "   Проверь что:"
  echo "   1. Rails сервер запущен (bin/dev)"
  echo "   2. ngrok запущен и URL правильный"
  echo "   3. Bot Token правильный"
fi

# 🎉 Echo Bot готов к тестированию!

## ✅ Что работает:

1. ✅ PostgreSQL запущен
2. ✅ Rails сервер работает на порту 3000
3. ✅ ngrok туннель активен: `https://unbeset-tressier-roselyn.ngrok-free.dev`
4. ✅ Telegram webhook установлен
5. ✅ API ключи настроены (Telegram + OpenAI)

---

## 🚀 Начни тестирование прямо сейчас!

### Шаг 1: Найди бота в Telegram
Открой Telegram и найди своего бота по username (который ты указал при создании через @BotFather)

### Шаг 2: Отправь /start
```
/start
```

Ожидается приветственное сообщение от бота

### Шаг 3: Попробуй другие команды
```
/help
/status
/settings
```

### Шаг 4: Отправь текстовое сообщение
```
Сегодня был продуктивный день
```

Бот должен:
- Проанализировать через GPT-4
- Определить тип (дневник/идея/план)
- Сохранить в базу
- Вернуть подтверждение

### Шаг 5: Отправь голосовое сообщение
Наговори что-нибудь на русском, например:
"У меня идея создать новый проект"

Бот должен:
- Показать "🎤 Обрабатываю..."
- Распознать речь через Whisper
- Проанализировать и сохранить

---

## 📊 Мониторинг

### Смотреть логи в реальном времени:
```bash
tail -f log/development.log
```

### Проверить что записи сохраняются:
```bash
bin/rails console
```

Затем:
```ruby
User.first
Entry.all
Entry.count
```

---

## 🔗 Полезные ссылки

**Webhook статус:**
```bash
curl "https://api.telegram.org/bot8256898686:AAEywKcZjRzZA1mgUsaUAsflgtXBn0Xj2bA/getWebhookInfo"
```

**ngrok Dashboard:**
http://localhost:4040

**Rails сервер проверка:**
```bash
curl http://localhost:3000/up
```

---

## 📖 Документация

- Подробные тесты: `TEST_GUIDE.md`
- Быстрый старт: `QUICK_START.md`
- Roadmap проекта: `PROJECT_ROADMAP.md`
- Чеклист запуска: `CHECKLIST.md`

---

## 🐛 Если что-то не работает

1. **Проверь процессы:**
   ```bash
   ps aux | grep -E "(rails|ngrok)" | grep -v grep
   ```

2. **Проверь логи:**
   ```bash
   tail -50 log/development.log
   ```

3. **Перезапусти всё:**
   ```bash
   # Остановить процессы
   pkill -f "rails server"
   pkill -f ngrok

   # Запустить заново
   bin/rails server -p 3000 > log/server.log 2>&1 &
   ngrok http 3000 > log/ngrok.log 2>&1 &

   # Получить новый ngrok URL
   sleep 3
   curl -s http://localhost:4040/api/tunnels | python3 -c "import sys, json; data = json.load(sys.stdin); print([t['public_url'] for t in data.get('tunnels', []) if t['public_url'].startswith('https')][0])"

   # Установить webhook с новым URL
   ./set_webhook.sh <НОВЫЙ_NGROK_URL>
   ```

---

## 🎯 Что делать после тестирования

1. Собери фидбек по UX
2. Определи что нужно улучшить в первую очередь
3. Продолжай с Фазой 2: Google Calendar интеграция
4. Или добавь векторный поиск похожих записей
5. Или улучши UX с inline кнопками

---

**Вопросы? Проблемы? Дай знать!**

**Удачного тестирования! 🚀**

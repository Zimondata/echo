# Настройка ngrok

ngrok требует регистрацию и authtoken для работы.

## Шаги:

### 1. Зарегистрируйся на ngrok (бесплатно)
https://dashboard.ngrok.com/signup

### 2. Получи authtoken
После регистрации перейди на:
https://dashboard.ngrok.com/get-started/your-authtoken

Скопируй свой authtoken (выглядит примерно так: `2abc123...`)

### 3. Установи authtoken
```bash
ngrok config add-authtoken <YOUR_AUTHTOKEN>
```

Пример:
```bash
ngrok config add-authtoken 2abc123def456ghi789jkl
```

### 4. Запусти ngrok
```bash
ngrok http 3000
```

### 5. Скопируй HTTPS URL
После запуска ngrok покажет что-то вроде:
```
Forwarding   https://abc123.ngrok.io -> http://localhost:3000
```

Скопируй этот `https://abc123.ngrok.io` URL

### 6. Установи webhook
```bash
./set_webhook.sh https://abc123.ngrok.io
```

Готово! 🎉

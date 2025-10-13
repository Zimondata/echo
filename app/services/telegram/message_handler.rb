module Telegram
  class MessageHandler
    attr_reader :user, :message, :chat_id

    def initialize(user, message)
      @user = user
      @message = message
      @chat_id = message.chat.id
    end

    def process
      # Send typing indicator
      BotService.send_typing(chat_id)

      # Handle different message types
      if message.text&.start_with?("/")
        handle_command
      elsif message.voice
        handle_voice_message
      elsif message.text
        handle_text_message
      else
        send_reply("Извините, я пока поддерживаю только текстовые и голосовые сообщения.")
      end
    end

    private

    def handle_command
      command = message.text.split.first.downcase

      case command
      when "/start"
        handle_start_command
      when "/help"
        handle_help_command
      when "/settings"
        handle_settings_command
      when "/status"
        handle_status_command
      else
        send_reply("Неизвестная команда. Используй /help для списка команд.")
      end
    end

    def handle_start_command
      welcome_text = <<~TEXT
        Привет, #{user.full_name}! 👋

        Я *Echo* — твой AI-ассистент для управления дневником, идеями и планами.

        Я умею:
        📔 Вести дневник твоих мыслей
        💡 Сохранять идеи и инсайты
        📅 Планировать задачи и события
        🔔 Напоминать о важном

        Просто отправь мне голосовое или текстовое сообщение, и я всё сохраню!

        Используй /help для подробной информации.
      TEXT

      send_reply(welcome_text)
    end

    def handle_help_command
      help_text = <<~TEXT
        *Команды:*

        /start — Начать работу
        /help — Показать это сообщение
        /settings — Настройки
        /status — Статистика твоих записей

        *Как использовать:*

        1️⃣ *Отправь сообщение* (текст или голос)
        Я автоматически определю, что это: дневник, идея или план.

        2️⃣ *Если это план с датой*, я создам событие в Google Calendar

        3️⃣ *Настрой напоминания*, и я буду присылать уведомления

        *Примеры:*

        💬 "Сегодня был продуктивный день, закончил проект"
        → Сохраню как запись в дневнике

        💬 "У меня идея создать AI-бота для планирования"
        → Сохраню как идею

        💬 "Завтра в 15:00 встреча с клиентом"
        → Создам событие в календаре и напоминание
      TEXT

      send_reply(help_text)
    end

    def handle_settings_command
      settings_text = <<~TEXT
        ⚙️ *Настройки*

        Текущие настройки:
        🌍 Язык: #{user.language}
        🕐 Часовой пояс: #{user.timezone}
        📅 Google Calendar: #{user.google_connected? ? "✅ Подключен" : "❌ Не подключен"}

        Для изменения настроек напиши мне, что хочешь изменить.
      TEXT

      send_reply(settings_text)
    end

    def handle_status_command
      entries_count = user.entries.active.count
      ideas_count = user.entries.ideas.count
      plans_count = user.entries.plans.count
      reminders_count = user.reminders.pending.count

      status_text = <<~TEXT
        📊 *Твоя статистика*

        📝 Всего записей: #{entries_count}
        💡 Идей: #{ideas_count}
        📅 Планов: #{plans_count}
        🔔 Активных напоминаний: #{reminders_count}

        Продолжай в том же духе! 🚀
      TEXT

      send_reply(status_text)
    end

    def handle_voice_message
      send_reply("🎤 Обрабатываю голосовое сообщение...")

      # Download audio file
      audio_data = BotService.download_file(message.voice.file_id)

      unless audio_data
        send_reply("Не удалось скачать аудио. Попробуй еще раз.")
        return
      end

      # Transcribe with Whisper
      transcript = Ai::WhisperService.transcribe(audio_data)

      unless transcript
        send_reply("Не удалось распознать речь. Попробуй еще раз.")
        return
      end

      # Process transcribed text
      process_content(transcript, audio_file_id: message.voice.file_id)
    end

    def handle_text_message
      process_content(message.text)
    end

    def process_content(text, audio_file_id: nil)
      # Analyze content with AI
      analysis = Ai::ContentAnalyzer.analyze(text, user: user)

      # Create entry
      entry = user.entries.create!(
        entry_type: analysis[:type],
        content: analysis[:summary] || text,
        transcript: text,
        audio_file_id: audio_file_id,
        priority: analysis[:priority] || 0,
        metadata: analysis[:metadata] || {}
      )

      # Send confirmation
      send_entry_confirmation(entry, analysis)

      # Create calendar event if needed
      if analysis[:create_calendar_event] && analysis[:event_time]
        create_calendar_event(entry, analysis)
      end

      # Create reminder if needed
      if analysis[:create_reminder] && analysis[:reminder_time]
        create_reminder(entry, analysis)
      end

    rescue StandardError => e
      Rails.logger.error "Error processing content: #{e.message}"
      send_reply("Произошла ошибка при обработке. Попробуй еще раз.")
    end

    def send_entry_confirmation(entry, analysis)
      type_emoji = case entry.entry_type
      when "diary" then "📔"
      when "idea" then "💡"
      when "plan" then "📅"
      else "📝"
      end

      confirmation_text = <<~TEXT
        #{type_emoji} *Записал!*

        *Тип:* #{entry_type_name(entry.entry_type)}
        *Дата:* #{I18n.l(entry.occurred_at, format: :long)}

        *Резюме:*
        #{entry.content}
      TEXT

      send_reply(confirmation_text)
    end

    def entry_type_name(type)
      {
        "diary" => "Дневник",
        "idea" => "Идея",
        "plan" => "План",
        "plan_update" => "Обновление плана"
      }[type] || type
    end

    def create_calendar_event(entry, analysis)
      # TODO: Implement Google Calendar integration
      # For now, just create a local calendar event
      event = user.calendar_events.create!(
        entry: entry,
        title: analysis[:event_title] || entry.content.truncate(100),
        description: entry.content,
        start_time: analysis[:event_time],
        end_time: analysis[:event_end_time] || (analysis[:event_time] + 1.hour),
        event_type: "plan"
      )

      send_reply("📅 Создал событие в календаре на #{I18n.l(event.start_time, format: :short)}")
    rescue StandardError => e
      Rails.logger.error "Error creating calendar event: #{e.message}"
    end

    def create_reminder(entry, analysis)
      reminder = user.reminders.create!(
        entry: entry,
        reminder_type: "one_time",
        remind_at: analysis[:reminder_time],
        message: analysis[:reminder_message] || entry.content.truncate(200)
      )

      send_reply("🔔 Напомню тебе #{I18n.l(reminder.remind_at, format: :short)}")
    rescue StandardError => e
      Rails.logger.error "Error creating reminder: #{e.message}"
    end

    def send_reply(text)
      BotService.send_message(
        chat_id: chat_id,
        text: text
      )
    end
  end
end

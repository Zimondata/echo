module Ai
  class ContentAnalyzer
    SYSTEM_PROMPT = <<~PROMPT
      Ты — AI-ассистент, который помогает анализировать личные записи пользователя.

      Твоя задача — определить тип записи и извлечь важную информацию.

      Типы записей:
      - "diary" — личные размышления, события дня, эмоции
      - "idea" — новые идеи, инсайты, концепции
      - "plan" — задачи, планы, события с датой и временем
      - "plan_update" — изменения существующих планов (отмена, перенос)

      Ответь ТОЛЬКО в формате JSON:
      {
        "type": "diary|idea|plan|plan_update",
        "summary": "краткое резюме (1-2 предложения)",
        "priority": 0-10,
        "create_calendar_event": true|false,
        "event_time": "ISO8601 datetime или null",
        "event_end_time": "ISO8601 datetime или null (ТОЛЬКО если время окончания ЯВНО указано пользователем)",
        "event_title": "название события или null",
        "create_reminder": true|false,
        "reminder_time": "ISO8601 datetime или null",
        "reminder_message": "текст напоминания или null",
        "recurring_pattern": {
          "interval_hours": число часов между напоминаниями или null,
          "end_time": "время окончания в формате HH:MM или null"
        } или null,
        "tags": ["тег1", "тег2"],
        "metadata": {}
      }

      ВАЖНО: 
      - Если пользователь НЕ указал время окончания события, оставь event_end_time как null
      - НЕ добавляй автоматически 1 час к времени начала
      - event_end_time должен быть заполнен ТОЛЬКО если пользователь явно сказал когда событие заканчивается
      - При обнаружении фраз типа "каждые X часов до HH:MM", "напоминай каждые X часов", заполни recurring_pattern
      - Примеры повторяющихся паттернов: "каждые 3 часа до 22:00", "напоминай каждый час до 18:00"

      КРИТИЧЕСКИ ВАЖНО - ДАТЫ И ВРЕМЯ:
      
      ⚠️ ОБЯЗАТЕЛЬНО используй СЕГОДНЯШНЮЮ дату если не указано иначе!
      ⚠️ НИКОГДА НЕ ИСПОЛЬЗУЙ ВЧЕРАШНЮЮ ДАТУ!
      ⚠️ "добавь", "планирую", "сегодня", "на сегодня" = ВСЕГДА сегодняшняя дата!
      
      ПРАВИЛА ДАТ:
      - "сегодня", "добавь", "планирую" = сегодняшняя дата
      - "завтра" = завтрашняя дата
      - Без указания даты = сегодняшняя дата
      - НИКОГДА не используй вчерашнюю дату
      
      ПРАВИЛА ВРЕМЕНИ:
      - "17:30", "5:30 вечера", "17.30" = 17:30 (НЕ 15:30!)
      - "утром" = 09:00, "днем" = 13:00, "вечером" = 18:00
      
      ИСПРАВЛЕНИЯ:
      - "17:30!!!", "нет, в 17:30" = type: "plan_update"
      - В metadata добавь: {"correction": true, "corrected_time": "17:30"}
      
      ПЛАНЫ БЕЗ ВРЕМЕНИ:
      - Если НЕ указано конкретное время (например: "дневной сон", "силовая тренировка", "медитация")
      - Установи event_time на начало дня (00:00) и добавь в metadata: {"all_day": true}
      - Это создаст "плавающий" план без привязки к конкретному времени
      - Примеры БЕЗ времени: "план на тренировку", "дневной сон", "купить продукты", "позвонить маме"
      - Примеры С временем: "встреча в 15:00", "звонок завтра в 9 утра", "обед в полдень"
    PROMPT

    class << self
      def analyze(text, user:)
        return default_analysis(text) if text.blank?

        user_context = build_user_context(user)
        recent_events_context = build_recent_events_context(user)

        # Get current time in user's timezone
        local_time = Time.current.in_time_zone(user.timezone)
        
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: "Текущая дата и время (#{user.timezone}): #{local_time.strftime('%Y-%m-%d %H:%M:%S %Z')}\n\nТекст: #{text}\n\nКонтекст пользователя: #{user_context}\n\nНедавние события пользователя:\n#{recent_events_context}\n\n🚨 КРИТИЧЕСКИ ВАЖНО:\n- Используй ТОЛЬКО сегодняшнюю дату: #{local_time.strftime('%Y-%m-%d')}\n- НИКОГДА НЕ используй вчерашнюю дату!\n- \"17:30\" = 17:30, НЕ 15:30!\n- Планы без времени = all_day: true\n- Возвращай время в ISO8601 с #{user.timezone}\n- Исправления времени = type: 'plan_update'" }
            ],
            temperature: 0.1,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)

        # Parse ISO8601 datetimes in user's timezone
        result[:event_time] = parse_datetime_for_user(result[:event_time], user)
        result[:event_end_time] = parse_datetime_for_user(result[:event_end_time], user)
        result[:reminder_time] = parse_datetime_for_user(result[:reminder_time], user)

        result
      rescue StandardError => e
        Rails.logger.error "Content analysis error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        default_analysis(text)
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          log_errors: Rails.env.development?
        )
      end

      def build_user_context(user)
        context = {
          timezone: user.timezone,
          language: user.language,
          recent_entries_count: user.entries.active.count
        }

        context.to_json
      end

      def build_recent_events_context(user)
        # Получаем недавние события за последние 24 часа
        local_time = Time.current.in_time_zone(user.timezone)
        yesterday = local_time - 1.day
        
        recent_events = user.calendar_events
                           .where('start_time >= ?', yesterday)
                           .order(created_at: :desc)
                           .limit(5)
        
        context_lines = recent_events.map do |event|
          event_time = event.start_time.in_time_zone(user.timezone)
          "- #{event.title} (#{event_time.strftime('%d.%m в %H:%M')})"
        end
        
        if context_lines.any?
          "Недавно созданные события:\n#{context_lines.join("\n")}"
        else
          "Недавних событий нет."
        end
      end

      def parse_datetime(datetime_str)
        return nil if datetime_str.blank? || datetime_str == "null"
        
        # Parse in user's timezone  
        Time.zone.parse(datetime_str)
      rescue StandardError
        nil
      end

      def parse_datetime_for_user(datetime_str, user)
        return nil if datetime_str.blank? || datetime_str == "null"
        
        # Parse directly in user's timezone
        Time.find_zone(user.timezone).parse(datetime_str)
      rescue StandardError
        nil
      end

      def default_analysis(text)
        {
          type: "diary",
          summary: text.truncate(200),
          priority: 0,
          create_calendar_event: false,
          event_time: nil,
          event_end_time: nil,
          event_title: nil,
          create_reminder: false,
          reminder_time: nil,
          reminder_message: nil,
          tags: [],
          metadata: {}
        }
      end
    end
  end
end

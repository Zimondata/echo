module Ai
  class MultiPlanAnalyzer
    SYSTEM_PROMPT = <<~PROMPT
      Ты — AI-ассистент, который анализирует голосовые сообщения пользователя и извлекает из них отдельные планы, задачи и события.

      Твоя задача:
      1. Внимательно прочитать весь текст
      2. Найти ВСЕ упоминания планов, задач, событий, встреч
      3. Разделить их на отдельные элементы
      4. Для каждого элемента определить время, приоритет и детали

      Типы записей:
      - "diary" — размышления, эмоции, события дня без конкретных планов
      - "idea" — новые идеи, концепции, инсайты
      - "plan" — конкретные задачи, планы, события с временем
      - "plan_update" — изменения существующих планов

      ВАЖНО: Если в тексте несколько планов - создавай отдельный объект для каждого!

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
      - "17:30", "17.30", "5:30 вечера" = 17:30 (сохраняй точное время!)
      - "9:00", "9 утра" = 09:00
      - "утром" без времени = начало дня + all_day: true
      - "днем" без времени = начало дня + all_day: true  
      - "вечером" без времени = начало дня + all_day: true
      
      ИСПРАВЛЕНИЯ:
      - "17:30!!!", "нет, в 17:30" = type: "plan_update"
      - В metadata добавь: {"correction": true, "corrected_time": "17:30"}
      
      ПЛАНЫ БЕЗ ВРЕМЕНИ:
      - Для "на сегодня" без времени → ВСЕГДА используй сегодняшнюю дату в полночь с часовым поясом
      - Для "на завтра" без времени → ВСЕГДА используй завтрашнюю дату в полночь с часовым поясом
      - ВАЖНО: НЕ КОНВЕРТИРУЙ В UTC! Используй часовой пояс пользователя напрямую!

      Ответь ТОЛЬКО в формате JSON:
      {
        "entries": [
          {
            "type": "diary|idea|plan|plan_update",
            "content": "полное содержание этого конкретного плана/записи",
            "summary": "краткое резюме (1-2 предложения)",
            "priority": 0-10,
            "create_calendar_event": true|false,
            "event_time": "ISO8601 datetime или null",
            "event_end_time": "ISO8601 datetime или null (ТОЛЬКО если время окончания ЯВНО указано)",
            "event_title": "название события или null",
            "create_reminder": true|false,
            "reminder_time": "ISO8601 datetime или null",
            "reminder_message": "текст напоминания или null",
            "tags": ["тег1", "тег2"],
            "metadata": {}
          }
        ]
      }

      Примеры:
      - "Утром в 9 встреча с клиентом, потом в обед нужно купить продукты, вечером в 19:00 тренировка" 
        → 3 отдельных плана
      - "Завтра встреча в 10 утра, а еще надо не забыть позвонить маме после 15:00"
        → 2 отдельных плана
      - "Сегодня хороший день, много работал"
        → 1 запись diary

      Всегда анализируй время относительно текущей даты и времени!
      
      ПЛАНЫ БЕЗ ВРЕМЕНИ:
      - Если НЕ указано конкретное время (например: "помедитировать", "силовая тренировка", "посмотреть фильм")
      - Установи event_time на начало дня (00:00) и добавь в metadata: {"all_day": true}
      - Это создаст "плавающий" план без привязки к конкретному времени
      - Примеры БЕЗ времени: "помедитировать", "тренировка", "купить продукты"
      - Примеры С временем: "встреча в 15:00", "звонок в 9 утра", "обед в полдень"
      
      КРИТИЧЕСКИ ВАЖНО - НАПОМИНАНИЯ:
      ⚠️ create_reminder = true ТОЛЬКО если пользователь ЯВНО просит напомнить!
      ⚠️ НЕ создавай напоминания автоматически для планов!
      
      СОЗДАВАЙ НАПОМИНАНИЯ только при словах:
      - "напомни", "напоминание", "напомнить"
      - "разбуди", "будильник" 
      - "уведоми", "сообщи"
      - "не забыть"
      
      НЕ СОЗДАВАЙ НАПОМИНАНИЯ для обычных планов:
      - "созвон в 14:00" = НЕТ напоминания (только календарное событие)
      - "встреча завтра" = НЕТ напоминания (только календарное событие)
      - "тренировка" = НЕТ напоминания (только план)
      
      СОЗДАВАЙ НАПОМИНАНИЯ только при прямом запросе:
      - "напомни о созвоне в 14:00" = ДА, напоминание
      - "уведоми о встрече за час" = ДА, напоминание

      КРИТИЧЕСКИ ВАЖНО:
      - event_end_time заполняй ТОЛЬКО если пользователь ЯВНО указал время окончания
      - НЕ добавляй автоматически 1 час к времени начала  
      - Если сказано "медитация в 6:00" - НЕ добавляй end_time
      - Если сказано "встреча с 10 до 12" - тогда добавляй end_time
    PROMPT

    class << self
      def analyze(text, user:)
        return [default_analysis(text)] if text.blank?
        
        # Set timezone for proper date parsing
        @user = user
        Time.zone = user.timezone

        user_context = build_user_context(user)
        recent_events_context = build_recent_events_context(user)

        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { 
                role: "user", 
                content: build_user_prompt(text, user_context, recent_events_context)
              }
            ],
            temperature: 0.1,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
        
        # Process each entry
        entries = result[:entries] || []
        
        entries.map do |entry|
          process_entry(entry, text)
        end.compact

      rescue StandardError => e
        Rails.logger.error "Multi-plan analysis error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        [default_analysis(text)]
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          log_errors: Rails.env.development?
        )
      end

      def build_user_context(user)
        {
          timezone: user.timezone,
          language: user.language,
          recent_entries_count: user.entries.active.count,
          current_time: Time.current.in_time_zone(user.timezone).iso8601
        }
      end

      def build_user_prompt(text, context, recent_events_context)
        current_date = Time.current.in_time_zone(context[:timezone])
        tomorrow_date = current_date + 1.day
        <<~PROMPT
          Текущая дата и время: #{context[:current_time]}
          Часовой пояс пользователя: #{context[:timezone]}
          Сегодняшняя дата: #{current_date.strftime('%Y-%m-%d')} (#{current_date.strftime('%A')})
          Завтрашняя дата: #{tomorrow_date.strftime('%Y-%m-%d')} (#{tomorrow_date.strftime('%A')})

          #{recent_events_context}

          Текст для анализа:
          "#{text}"

          Найди ВСЕ планы, задачи и события в этом тексте и создай для каждого отдельную запись.
          Обрати внимание на слова: "потом", "затем", "еще", "также", "а еще", "после этого", "и" - они часто разделяют разные планы.
          
          🚨 КРИТИЧЕСКИ ВАЖНО - ИСПОЛЬЗУЙ ЭТИ ТОЧНЫЕ ЗНАЧЕНИЯ:
          - Для "на сегодня" БЕЗ времени: event_time = "#{current_date.strftime('%Y-%m-%dT00:00:00%:z')}"
          - Для "на завтра" БЕЗ времени: event_time = "#{tomorrow_date.strftime('%Y-%m-%dT00:00:00%:z')}"
          - Для "на сегодня в 15:00": event_time = "#{current_date.strftime('%Y-%m-%d')}T15:00:00#{current_date.strftime('%:z')}"
          - Для "на завтра в 9:00": event_time = "#{tomorrow_date.strftime('%Y-%m-%d')}T09:00:00#{tomorrow_date.strftime('%:z')}"
          - НИКОГДА не используй дату #{(current_date - 1.day).strftime('%Y-%m-%d')} или более ранние!
          - Всегда добавляй metadata: {"all_day": true} для планов без времени
          - НЕ конвертируй в UTC! Используй часовой пояс #{context[:timezone]} напрямую!
          - НЕ создавай напоминания автоматически!
        PROMPT
      end

      def process_entry(entry, original_text)
        # Ensure we have required fields
        entry[:type] ||= determine_type_fallback(entry[:content] || original_text)
        entry[:content] ||= original_text
        entry[:summary] ||= (entry[:content] || original_text).truncate(200)
        entry[:priority] ||= 0

        # Parse datetimes
        entry[:event_time] = parse_datetime(entry[:event_time])
        entry[:event_end_time] = parse_datetime(entry[:event_end_time])
        entry[:reminder_time] = parse_datetime(entry[:reminder_time])

        # Ensure arrays and hashes
        entry[:tags] ||= []
        entry[:metadata] ||= {}

        # Add source info to metadata
        entry[:metadata][:extracted_from_multi_plan] = true
        entry[:metadata][:original_text] = original_text

        entry
      end

      def determine_type_fallback(text)
        text_lower = text.downcase

        # Check for time-related keywords for plans
        plan_keywords = %w[встреча собрание созвон звонок тренировка занятие урок дела купить сделать выполнить завершить]
        idea_keywords = %w[идея мысль концепция предложение придумать разработать создать изобрести]
        
        if plan_keywords.any? { |keyword| text_lower.include?(keyword) }
          'plan'
        elsif idea_keywords.any? { |keyword| text_lower.include?(keyword) }
          'idea'
        else
          'diary'
        end
      end

      def parse_datetime(datetime_str)
        return nil if datetime_str.blank? || datetime_str == "null"
        Time.zone.parse(datetime_str)
      rescue StandardError => e
        Rails.logger.warn "Failed to parse datetime: #{datetime_str} - #{e.message}"
        nil
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

      def default_analysis(text)
        {
          type: "diary",
          content: text,
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
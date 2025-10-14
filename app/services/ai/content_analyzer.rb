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
    PROMPT

    class << self
      def analyze(text, user:)
        return default_analysis(text) if text.blank?

        user_context = build_user_context(user)

        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: "Текущая дата и время: #{Time.current.iso8601}\n\nТекст: #{text}\n\nКонтекст пользователя: #{user_context}" }
            ],
            temperature: 0.3,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)

        # Parse ISO8601 datetimes
        result[:event_time] = parse_datetime(result[:event_time])
        result[:event_end_time] = parse_datetime(result[:event_end_time])
        result[:reminder_time] = parse_datetime(result[:reminder_time])

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

      def parse_datetime(datetime_str)
        return nil if datetime_str.blank? || datetime_str == "null"
        Time.zone.parse(datetime_str)
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

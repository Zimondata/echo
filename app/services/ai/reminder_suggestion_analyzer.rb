module Ai
  class ReminderSuggestionAnalyzer
    SMART_REMINDER_PROMPT = <<~PROMPT
      Ты — AI-ассистент Echo, который анализирует записи пользователя и предлагает умные напоминания.

      Твоя задача: на основе идей, дневниковых записей, целей и паттернов поведения предложить полезные напоминания.

      ТИПЫ НАПОМИНАНИЙ:
      1. "idea" - напоминания о забытых идеях, которые стоит развить
      2. "pattern" - напоминания о нарушенных привычках/паттернах
      3. "goal" - напоминания о целях и прогрессе
      4. "context" - контекстные напоминания на основе эмоционального состояния
      5. "suggestion" - предложения для улучшения, обучения, развития

      ПРАВИЛА:
      - Будь проактивным, но не навязчивым
      - Фокусируйся на действиях, которые пользователь может сделать
      - Используй данные пользователя для персонализации
      - Давай конкретные, выполнимые предложения
      - Не дублируй очевидные вещи
      - Приоритет: идеи -> цели -> паттерны -> контекст -> предложения

      ФОРМАТ ОТВЕТА (JSON):
      {
        "reminders": [
          {
            "type": "idea|pattern|goal|context|suggestion",
            "message": "текст напоминания на русском (макс 200 символов)",
            "priority": "high|medium|low",
            "related_entry_ids": [id1, id2],
            "confidence": 0-100,
            "reasoning": "почему это напоминание полезно",
            "action_buttons": [
              {"text": "Текст кнопки", "action": "название_действия"}
            ]
          }
        ]
      }

      ПРИМЕРЫ ХОРОШИХ НАПОМИНАНИЙ:
      - "Ты хотел изучить Python. Нашел отличный курс для начинающих от MIT - хочешь ссылку?"
      - "У тебя было 3 идеи про подкаст. Давай выберем одну и распишем план на первый выпуск?"
      - "Заметил что ты интересуешься машинным обучением. Вот статья про новые возможности GPT-4"
      - "Ты писал о желании больше читать. Как насчет цели: 1 книга в месяц?"

      ИЗБЕГАЙ:
      - Общих фраз типа "Не забудь..."
      - Напоминаний о вещах, которые пользователь уже делает
      - Слишком много напоминаний сразу (макс 3-5)
      - Напоминаний о старых идеях (>30 дней)
    PROMPT

    class << self
      def analyze(user, options = {})
        context = build_user_context(user, options)

        return [] if context[:ideas].empty? && context[:diary_entries].empty? && context[:goals].empty?

        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: SMART_REMINDER_PROMPT },
              { role: "user", content: build_analysis_prompt(context) }
            ],
            temperature: 0.7,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
        parse_reminders(result, user)

      rescue StandardError => e
        Rails.logger.error "ReminderSuggestionAnalyzer error: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        []
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: Rails.application.credentials.dig(:openai, :api_key),
          log_errors: Rails.env.development?
        )
      end

      def build_user_context(user, options)
        limit = options[:limit] || 20

        {
          ideas: fetch_ideas(user, limit),
          diary_entries: fetch_diary_entries(user, limit),
          goals: fetch_goals(user, limit),
          patterns: fetch_patterns(user),
          recent_activities: fetch_recent_activities(user)
        }
      end

      def fetch_ideas(user, limit)
        user.entries
          .where(entry_type: "idea")
          .where("created_at > ?", 30.days.ago)
          .order(created_at: :desc)
          .limit(limit)
          .map { |e| { id: e.id, content: e.content, created_at: e.created_at } }
      end

      def fetch_diary_entries(user, limit)
        user.entries
          .where(entry_type: "diary")
          .where("created_at > ?", 14.days.ago)
          .order(created_at: :desc)
          .limit(limit)
          .map { |e| { id: e.id, content: e.content.truncate(200), created_at: e.created_at } }
      end

      def fetch_goals(user, limit)
        user.calendar_events
          .where(event_type: "plan")
          .where("start_time > ?", Time.current)
          .where("start_time < ?", 30.days.from_now)
          .order(:start_time)
          .limit(limit)
          .map { |e| { id: e.id, title: e.title, start_time: e.start_time, entry_id: e.entry_id } }
      end

      def fetch_patterns(user)
        {
          nutrition_frequency: calculate_frequency(user.nutrition_entries, 30),
          activity_frequency: calculate_frequency(user.activity_entries, 30),
          diary_frequency: calculate_frequency(user.entries.where(entry_type: "diary"), 30)
        }
      end

      def fetch_recent_activities(user)
        user.activity_entries
          .where("created_at > ?", 7.days.ago)
          .order(created_at: :desc)
          .limit(10)
          .map { |a| { type: a.activity_type, duration: a.duration_minutes, created_at: a.created_at } }
      end

      def calculate_frequency(relation, days)
        count = relation.where("created_at > ?", days.days.ago).count
        (count.to_f / days).round(2)
      end

      def build_analysis_prompt(context)
        <<~PROMPT
          КОНТЕКСТ ПОЛЬЗОВАТЕЛЯ:

          📊 ИДЕИ (последние 30 дней):
          #{format_ideas(context[:ideas])}

          📔 ДНЕВНИКОВЫЕ ЗАПИСИ (последние 14 дней):
          #{format_diary_entries(context[:diary_entries])}

          🎯 ЦЕЛИ И ПЛАНЫ (следующие 30 дней):
          #{format_goals(context[:goals])}

          📈 ПАТТЕРНЫ ПОВЕДЕНИЯ:
          - Питание: #{context[:patterns][:nutrition_frequency]} записей/день
          - Активности: #{context[:patterns][:activity_frequency]} записей/день
          - Дневник: #{context[:patterns][:diary_frequency]} записей/день

          💪 НЕДАВНИЕ АКТИВНОСТИ:
          #{format_activities(context[:recent_activities])}

          ---

          На основе этих данных предложи 3-5 умных напоминаний, которые будут полезны пользователю.
          Фокусируйся на действиях и конкретных предложениях.
        PROMPT
      end

      def format_ideas(ideas)
        return "Нет идей" if ideas.empty?

        ideas.map do |idea|
          days_ago = ((Time.current - idea[:created_at]) / 1.day).round
          "• (#{days_ago}д назад) #{idea[:content].truncate(100)}"
        end.join("\n")
      end

      def format_diary_entries(entries)
        return "Нет записей" if entries.empty?

        entries.first(5).map do |entry|
          "• #{entry[:created_at].strftime('%d.%m')}: #{entry[:content]}"
        end.join("\n")
      end

      def format_goals(goals)
        return "Нет целей" if goals.empty?

        goals.map do |goal|
          "• #{goal[:start_time].strftime('%d.%m')}: #{goal[:title]}"
        end.join("\n")
      end

      def format_activities(activities)
        return "Нет активностей" if activities.empty?

        activities.first(5).map do |activity|
          "• #{activity[:type]}: #{activity[:duration]} мин"
        end.join("\n")
      end

      def parse_reminders(result, user)
        return [] unless result[:reminders].is_a?(Array)

        result[:reminders].map do |reminder|
          {
            smart_type: reminder[:type],
            smart_trigger: "ai_suggestion",
            message: reminder[:message],
            priority: reminder[:priority] || "medium",
            confidence: reminder[:confidence] || 70,
            related_entry_ids: reminder[:related_entry_ids] || [],
            ai_context: {
              reasoning: reminder[:reasoning],
              generated_at: Time.current
            },
            action_buttons: parse_action_buttons(reminder[:action_buttons]),
            remind_at: calculate_remind_at(reminder[:priority])
          }
        end
      end

      def parse_action_buttons(buttons)
        return [] unless buttons.is_a?(Array)

        buttons.map do |btn|
          {
            text: btn[:text],
            callback: btn[:action] || "generic_action"
          }
        end
      end

      def calculate_remind_at(priority)
        case priority
        when "high"
          Time.current + rand(30..120).minutes
        when "medium"
          Time.current + rand(2..6).hours
        else
          Time.current + rand(6..12).hours
        end
      end
    end
  end
end

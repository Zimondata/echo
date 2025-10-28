module Ai
  class CorrectionDetector
    CORRECTION_SYSTEM_PROMPT = <<~PROMPT
      Ты — AI-ассистент, который определяет, является ли новое сообщение пользователя ИСПРАВЛЕНИЕМ к недавно созданной записи.

      Твоя задача: проанализировать новое сообщение и определить:
      1. Это исправление/корректировка предыдущей записи?
      2. Какие именно поля нужно исправить?
      3. На какие новые значения?

      ИНДИКАТОРЫ ИСПРАВЛЕНИЯ:
      - "Нет, не так", "Исправляю", "Поправка"
      - "В 17:00, а не в 16:00"
      - "Калорий было 300, а не 200"
      - "Это не идея, а план"
      - "БЖУ неправильное"
      - "Неправильно распознал"
      - Исправление времени: "в 17:30!!!", "нет, в семнадцать тридцать"
      - Исправление данных питания: "белков было 25, а не 15"
      - Исправление классификации: "это план, а не идея"
      - Исправление еды: "это не паштет, это тунец", "нет, это был банан", "неправильно, это курица"
      - Уточнение продуктов: когда пользователь говорит что еда была другой в течение 5 минут после записи

      ТИПЫ ИСПРАВЛЕНИЙ:
      1. "time_correction" - исправление времени событий
      2. "nutrition_correction" - исправление БЖУ/калорий
      3. "content_correction" - исправление содержания
      4. "type_correction" - исправление типа записи (idea -> plan, etc.)
      5. "not_correction" - это не исправление, а новая запись

      Ответь ТОЛЬКО в формате JSON:
      {
        "is_correction": true|false,
        "correction_type": "time_correction|nutrition_correction|content_correction|type_correction|not_correction",
        "confidence": 0-100,
        "target_entry_type": "entry|nutrition|activity|null",
        "corrections": {
          "time": "новое время в ISO8601 или null",
          "nutrition": {
            "calories": число или null,
            "protein": число или null,
            "fat": число или null,
            "carbs": число или null
          },
          "content": "новое содержание или null",
          "entry_type": "новый тип записи или null",
          "activity_data": {
            "duration_minutes": число или null,
            "distance_km": число или null,
            "calories_burned": число или null
          }
        },
        "reasoning": "объяснение почему это исправление или нет"
      }

      ПРИМЕРЫ:

      Предыдущая запись: "Протеин на воде в обед" (БЖУ: белки 25г, калории 120)
      Новое сообщение: "Белков было 30, а не 25"
      → is_correction: true, correction_type: "nutrition_correction"

      Предыдущая запись: "Встреча завтра в 16:00"
      Новое сообщение: "В 17:00, а не в 16:00"
      → is_correction: true, correction_type: "time_correction"

      Предыдущая запись: "Нужно доделать проект" (тип: idea)
      Новое сообщение: "Это план на завтра, а не просто идея"
      → is_correction: true, correction_type: "type_correction"

      Предыдущая запись: "Бег 30 минут"
      Новое сообщение: "Бегал час, а не полчаса"
      → is_correction: true, correction_type: "content_correction"

      Предыдущая запись: "Съел тост с паштетом" (питание)
      Новое сообщение: "Это не паштет, это тунец"
      → is_correction: true, correction_type: "content_correction"

      Предыдущая запись: "Съел банан" (питание)
      Новое сообщение: "Нет, это было яблоко"
      → is_correction: true, correction_type: "content_correction"

      НЕ ИСПРАВЛЕНИЯ:
      - Новые планы или идеи
      - Дополнительная информация без исправления
      - Общие комментарии
      - Новые записи о питании (если прошло больше 5 минут)

      БУДЬ КОНСЕРВАТИВЕН: если сомневаешься — это НЕ исправление.
    PROMPT

    class << self
      def analyze(text, recent_entries, user:)
        return not_correction_result("Нет недавних записей") if recent_entries.empty?
        
        # Set timezone for proper date parsing
        Time.zone = user.timezone

        recent_entries_context = build_recent_entries_context(recent_entries)

        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: CORRECTION_SYSTEM_PROMPT },
              { 
                role: "user", 
                content: build_correction_prompt(text, recent_entries_context, user)
              }
            ],
            temperature: 0.1,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
        
        # Process and validate the result
        process_correction_result(result, recent_entries)

      rescue StandardError => e
        Rails.logger.error "Correction detection error: #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.first(3).join("\n")}"
        Rails.logger.error "Text: #{text}"
        Rails.logger.error "Recent entries count: #{recent_entries.count}"
        not_correction_result("Ошибка анализа: #{e.message}")
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          log_errors: Rails.env.development?
        )
      end

      def build_recent_entries_context(recent_entries)
        recent_entries.map.with_index(1) do |entry, index|
          context = "#{index}. #{entry.entry_type.upcase}: #{entry.content}"
          
          # Add nutrition data if present
          if entry.nutrition_entry
            nutrition = entry.nutrition_entry
            context += " (Калории: #{nutrition.calories}, Белки: #{nutrition.protein}г, Жиры: #{nutrition.fat}г, Углеводы: #{nutrition.carbs}г)"
          end
          
          # Add activity data if present - Note: Entry doesn't have direct activity_entries association
          # This would need to be handled differently if we want to support activity corrections
          
          # Add time if it's a plan with calendar event
          if entry.calendar_event
            time_str = entry.calendar_event.start_time.in_time_zone(Time.zone).strftime('%H:%M')
            context += " (Время: #{time_str})"
          end
          
          context
        end.join("\n")
      end

      def build_correction_prompt(text, recent_entries_context, user)
        current_time = Time.current.in_time_zone(user.timezone)
        
        <<~PROMPT
          Текущее время: #{current_time.strftime('%Y-%m-%d %H:%M')} (#{user.timezone})
          
          НЕДАВНИЕ ЗАПИСИ ПОЛЬЗОВАТЕЛЯ (последние 5 минут):
          #{recent_entries_context}
          
          НОВОЕ СООБЩЕНИЕ ПОЛЬЗОВАТЕЛЯ:
          "#{text}"
          
          Проанализируй: является ли новое сообщение исправлением к одной из недавних записей?
          
          ВАЖНО:
          - Ищи прямые указания на исправление
          - Обращай внимание на слова "нет", "не так", "исправляю", "поправка"
          - Ищи конкретные числовые исправления
          - Если это просто дополнительная информация — это НЕ исправление
          - Если сомневаешься — это НЕ исправление
        PROMPT
      end

      def process_correction_result(result, recent_entries)
        return not_correction_result("Низкая уверенность") if result[:confidence] < 70
        
        # Find the target entry for correction
        target_entry = determine_target_entry(result, recent_entries)
        
        result.merge(
          target_entry: target_entry,
          processed: true
        )
      end

      def determine_target_entry(result, recent_entries)
        # Simple heuristic: use the most recent entry of the matching type
        case result[:correction_type]
        when "nutrition_correction"
          recent_entries.find { |e| e.nutrition_entry.present? }
        when "time_correction"
          recent_entries.find { |e| e.calendar_event.present? }
        when "content_correction", "type_correction"
          recent_entries.first # Most recent entry
        else
          recent_entries.first
        end
      end

      def not_correction_result(reason)
        {
          is_correction: false,
          correction_type: "not_correction",
          confidence: 0,
          target_entry_type: nil,
          corrections: {},
          reasoning: reason,
          target_entry: nil,
          processed: true
        }
      end
    end
  end
end
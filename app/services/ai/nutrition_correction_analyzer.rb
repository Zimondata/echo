module Ai
  class NutritionCorrectionAnalyzer
    SYSTEM_PROMPT = <<~PROMPT
      Ты — специалист по анализу исправлений данных питания. 

      Твоя задача: извлечь ВСЕ данные о питании из текста исправления и дать максимально точные БЖУ данные.

      ВАЖНО: 
      - Анализируй ВЕСЬ продукт целиком, не только упомянутые части
      - Если упоминается "тунец в масле" - дай данные для порции тунца В МАСЛЕ
      - Используй реальные данные о калорийности продуктов
      - Если пользователь указывает ограничения (например "углеводов не больше 50") - следуй им

      Ответь ТОЛЬКО в формате JSON:
      {
        "calories": число_калорий_или_null,
        "protein": число_белков_в_граммах_или_null, 
        "fat": число_жиров_в_граммах_или_null,
        "carbs": число_углеводов_в_граммах_или_null,
        "food_items": "список_продуктов_через_запятую",
        "confidence": 0-100
      }

      СПРАВОЧНЫЕ ДАННЫЕ ПО ПРОДУКТАМ (на 100г):
      - Тунец консервированный в масле: 190 ккал, 25г белка, 9г жира, 0г углеводов
      - Тунец консервированный в воде: 130 ккал, 28г белка, 1г жира, 0г углеводов  
      - Оливковое масло: 884 ккал, 0г белка, 100г жира, 0г углеводов
      - Авокадо: 160 ккал, 2г белка, 15г жира, 9г углеводов
      - Банан: 89 ккал, 1г белка, 0.3г жира, 23г углеводов
      - Паштет печеночный: 314 ккал, 11г белка, 28г жира, 3г углеводов
      - Тост хлебный: 280 ккал, 8г белка, 3г жира, 56г углеводов

      ПРИМЕРЫ:

      Текст: "тунец в оливковом масле"
      → calories: 200, protein: 26, fat: 10, carbs: 0, food_items: "тунец, оливковое масло"

      Текст: "авокадо целый"  
      → calories: 160, protein: 2, fat: 15, carbs: 9, food_items: "авокадо"

      Текст: "углеводов там не больше 50"
      → calories: null, protein: null, fat: null, carbs: 50, food_items: null
    PROMPT

    class << self
      def analyze(correction_text, user:)
        Time.zone = user.timezone

        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: correction_text }
            ],
            temperature: 0.1,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
        
        # Validate and clean result
        {
          calories: result[:calories]&.to_f,
          protein: result[:protein]&.to_f,
          fat: result[:fat]&.to_f, 
          carbs: result[:carbs]&.to_f,
          food_items: result[:food_items],
          confidence: result[:confidence] || 70
        }

      rescue StandardError => e
        Rails.logger.error "Nutrition correction analysis error: #{e.message}"
        Rails.logger.error e.backtrace.first(3).join("\n")
        
        # Return empty result on error
        {
          calories: nil,
          protein: nil,
          fat: nil,
          carbs: nil,
          food_items: nil,
          confidence: 0
        }
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: Rails.application.credentials.dig(:openai, :api_key),
          log_errors: Rails.env.development?
        )
      end
    end
  end
end
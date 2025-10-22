module Ai
  class VisionService
    FOOD_ANALYSIS_PROMPT = <<~PROMPT
      Ты — эксперт по анализу питания. Проанализируй фото еды и предоставь данные в JSON формате.

      Твоя задача:
      1. Определить ВСЕ продукты на фото
      2. Оценить примерные порции и вес
      3. Рассчитать калории и БЖУ
      4. Определить тип приёма пищи
      5. Дать краткое описание

      Ответь ТОЛЬКО в формате JSON:
      {
        "description": "краткое описание блюда (1-2 предложения)",
        "food_items": ["продукт1", "продукт2", "продукт3"],
        "meal_type": "breakfast|lunch|dinner|snack",
        "confidence_score": 70-95,
        "nutrition": {
          "calories": число,
          "protein": число в граммах,
          "fat": число в граммах,
          "carbs": число в граммах
        },
        "portion_analysis": {
          "estimated_weight": "примерный вес в граммах",
          "portion_size": "small|medium|large",
          "serving_count": число порций
        },
        "quality_indicators": {
          "healthiness_score": 1-10,
          "processing_level": "minimal|moderate|high",
          "meal_balance": "balanced|carb-heavy|protein-heavy|fat-heavy"
        }
      }

      ВАЖНЫЕ ПРАВИЛА:
      - Будь максимально точным в подсчёте калорий
      - Учитывай ВСЕ видимые ингредиенты и добавки (масло, соусы, специи)
      - Если сомневаешься в порции, округляй в БОЛЬШУЮ сторону
      - confidence_score должен отражать твою уверенность в анализе
      - Если это не еда, верни confidence_score: 0 и description: "Не удалось распознать еду на фото"

      ПРИМЕРЫ АНАЛИЗА:
      - Салат: ~150 ккал, белки 5г, жиры 12г, углеводы 8г
      - Овсянка с бананом: ~300 ккал, белки 10г, жиры 6г, углеводы 55г  
      - Стейк с картошкой: ~650 ккал, белки 45г, жиры 30г, углеводы 35г
      - Суп: ~200 ккал, белки 8г, жиры 5г, углеводы 25г

      ОПРЕДЕЛЕНИЕ meal_type:
      - breakfast: каши, яичница, тосты, йогурт, мюсли
      - lunch: супы, горячие блюда, салаты с белками
      - dinner: мясо/рыба с гарниром, пасты, большие порции
      - snack: фрукты, орехи, печенье, небольшие порции
    PROMPT

    class << self
      def analyze_food_photo(image_data)
        return nil if image_data.blank?

        # Encode image to base64
        base64_image = Base64.strict_encode64(image_data)

        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
              {
                role: "user",
                content: [
                  {
                    type: "text",
                    text: FOOD_ANALYSIS_PROMPT
                  },
                  {
                    type: "image_url",
                    image_url: {
                      url: "data:image/jpeg;base64,#{base64_image}",
                      detail: "high"
                    }
                  }
                ]
              }
            ],
            max_tokens: 1000,
            temperature: 0.1,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
        
        # Validate result
        if result[:confidence_score] == 0
          Rails.logger.warn "VisionService: Not food detected - #{result[:description]}"
          return nil
        end

        # Ensure nutrition data exists and is valid
        unless result[:nutrition] && result[:nutrition][:calories].to_i > 0
          Rails.logger.warn "VisionService: Invalid nutrition data"
          return nil
        end

        result
      rescue StandardError => e
        Rails.logger.error "VisionService error: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        nil
      end

      def analyze_food_text(text)
        # Fallback method for text-based food analysis
        # Could be used when photo analysis fails
        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              {
                role: "system",
                content: "Проанализируй описание еды и верни данные в том же JSON формате, что и для фото. Используй стандартные порции и калорийность продуктов."
              },
              {
                role: "user",
                content: text
              }
            ],
            temperature: 0.1,
            response_format: { type: "json_object" }
          }
        )

        JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
      rescue StandardError => e
        Rails.logger.error "VisionService text analysis error: #{e.message}"
        nil
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          log_errors: Rails.env.development?
        )
      end
    end
  end
end
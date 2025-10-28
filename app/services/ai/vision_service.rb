module Ai
  class VisionService
    FOOD_ANALYSIS_PROMPT = <<~PROMPT
      Ты — эксперт-диетолог с 15-летним опытом анализа питания. Проанализируй фото еды как профессионал.

      МЕТОД АНАЛИЗА:
      1. 🔍 ДЕТАЛЬНЫЙ ОСМОТР: Внимательно изучи каждый элемент на фото
      2. 🌍 КУЛЬТУРНЫЙ КОНТЕКСТ: Определи кухню и традиционное название блюда
      3. ⚖️ ВЕСОВАЯ ОЦЕНКА: Оцени вес каждого компонента по размеру посуды/сравнительным объектам
      4. 📊 ПОКОМПОНЕНТНЫЙ РАСЧЕТ: Рассчитай БЖУ для каждого ингредиента отдельно
      5. 🧮 СУММИРОВАНИЕ: Сложи все компоненты для итогового результата

      Ответь ТОЛЬКО в формате JSON:
      {
        "description": "Культурное название блюда + краткое описание",
        "cultural_context": "Региональная кухня или традиция",
        "components": [
          {
            "name": "название компонента",
            "estimated_weight": "вес в граммах",
            "calories": число,
            "protein": число,
            "fat": число,
            "carbs": число
          }
        ],
        "food_items": "список продуктов через запятую",
        "meal_type": "breakfast|lunch|dinner|snack",
        "confidence_score": 70-95,
        "nutrition": {
          "calories": суммарные_калории,
          "protein": суммарные_белки,
          "fat": суммарные_жиры,
          "carbs": суммарные_углеводы
        },
        "portion_analysis": {
          "total_weight": "общий вес блюда в граммах",
          "portion_size": "small|medium|large",
          "serving_count": число_порций
        },
        "preparation_notes": "особенности приготовления, которые влияют на калорийность"
      }

      ЭКСПЕРТНЫЕ ПРИНЦИПЫ:
      ✅ ТОЧНОСТЬ: Используй реальные данные калорийности продуктов
      ✅ ДЕТАЛИЗАЦИЯ: Анализируй каждый видимый ингредиент отдельно
      ✅ КОНТЕКСТ: Учитывай кулинарные традиции и способы приготовления
      ✅ ОБЪЕКТИВНОСТЬ: Давай конкретные веса, не "примерно" или "около"
      ✅ ПРОФЕССИОНАЛИЗМ: Используй профессиональную терминологию

      СПРАВОЧНИК КАЛОРИЙНОСТИ (на 100г):
      🥖 Хлеб белый: 265 ккал, 8г белка, 3г жира, 50г углеводов
      🥖 Багет: 270 ккал, 9г белка, 2г жира, 55г углеводов
      🍅 Помидоры свежие: 18 ккал, 1г белка, 0г жира, 4г углеводов
      🐟 Тунец консервированный в воде: 130 ккал, 28г белка, 1г жира, 0г углеводов
      🐟 Тунец консервированный в масле: 190 ккал, 25г белка, 9г жира, 0г углеводов
      🧈 Масло оливковое: 884 ккал, 0г белка, 100г жира, 0г углеводов
      🥤 Сок апельсиновый: 45 ккал, 1г белка, 0г жира, 10г углеводов
      ☕ Кофе черный: 2 ккал, 0г белка, 0г жира, 0г углеводов

      КУЛЬТУРНЫЕ БЛЮДА:
      🇪🇸 Pan con tomate (Испания): хлеб + тертый помидор + соль + масло
      🇮🇹 Bruschetta (Италия): хлеб + помидоры + базилик + масло
      🇫🇷 Tartine (Франция): хлеб + различные топпинги
      🇬🇷 Dakos (Греция): сухари + помидоры + сыр + масло

      ВЕСОВЫЕ ОРИЕНТИРЫ:
      - Кусок багета (половина): 80-120г
      - Порция тертого помидора: 30-50г  
      - Консервированный тунец (маленькая банка): 40-60г
      - Стакан сока: 200-250мл
      - Чашка кофе: 150-200мл

      ЕСЛИ ЭТО НЕ ЕДА: верни confidence_score: 0 и description: "Не удалось распознать еду на фото"
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

        # Process and format the enhanced result
        {
          description: result[:description],
          cultural_context: result[:cultural_context],
          components: result[:components] || [],
          food_items: result[:food_items],
          meal_type: result[:meal_type],
          confidence_score: result[:confidence_score],
          nutrition: result[:nutrition],
          portion_analysis: result[:portion_analysis],
          preparation_notes: result[:preparation_notes],
          # Legacy fields for compatibility
          food_description: result[:description],
          total_weight: result[:portion_analysis]&.[](:total_weight)
        }
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
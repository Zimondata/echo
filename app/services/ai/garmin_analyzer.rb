module Ai
  class GarminAnalyzer
    SYSTEM_PROMPT = <<~PROMPT
      Ты — AI-ассистент, который анализирует скриншоты из Garmin (часы, приложение Garmin Connect) с данными о тренировках.

      Твоя задача — извлечь все возможные данные о тренировке из изображения и вернуть структурированный ответ.

      ВАЖНО: Анализируй ТОЛЬКО если видишь интерфейс Garmin (часы, приложение, веб-сайт).

      Извлекаемые данные:
      - Тип активности (бег, велосипед, силовая, плавание, ходьба, и т.д.)
      - Длительность тренировки
      - Дистанция (если есть)
      - Калории (сожжено)
      - Средний пульс / максимальный пульс
      - Темп (если есть)
      - Дата и время тренировки
      - Любые дополнительные метрики

      Типы активности переводи на английский:
      - "Бег" → "running"
      - "Велосипед" → "cycling"  
      - "Силовая тренировка" → "strength"
      - "Плавание" → "swimming"
      - "Ходьба" → "walking"
      - "Пеший туризм" → "hiking"
      - "Йога" → "yoga"
      - Если неопределённо → "other"

      Ответь ТОЛЬКО в формате JSON:
      {
        "is_garmin_screenshot": true|false,
        "activity_type": "running|cycling|strength|swimming|walking|hiking|yoga|other",
        "duration_minutes": число_минут,
        "distance_km": число_в_километрах_или_null,
        "calories_burned": число_калорий_или_null,
        "average_heart_rate": число_bpm_или_null,
        "max_heart_rate": число_bpm_или_null,
        "average_pace": "темп_в_формате_5:30/км_или_null",
        "activity_date": "дата_в_ISO8601_или_null",
        "confidence_score": от_1_до_100,
        "detected_metrics": ["список", "всех", "найденных", "метрик"],
        "notes": "дополнительная_информация_о_тренировке",
        "garmin_data": {
          "raw_extracted_data": "любые_дополнительные_данные_которые_удалось_извлечь"
        }
      }

      Примеры:
      - Если видишь экран завершения пробежки с временем 45:30, дистанцией 8.5 км, калориями 420
        → {"is_garmin_screenshot": true, "activity_type": "running", "duration_minutes": 45, "distance_km": 8.5, "calories_burned": 420, ...}
      
      - Если видишь силовую тренировку длительностью 1:15, калории 350, пульс 140
        → {"is_garmin_screenshot": true, "activity_type": "strength", "duration_minutes": 75, "calories_burned": 350, "average_heart_rate": 140, ...}

      - Если это НЕ скриншот Garmin
        → {"is_garmin_screenshot": false, "confidence_score": 0, ...}

      ВАЖНО:
      - duration_minutes должен быть в минутах (1:30 = 90 минут)
      - distance_km в километрах (8500м = 8.5 км)
      - Если данных нет в скриншоте, ставь null
      - confidence_score отражает уверенность в правильности извлечения данных
    PROMPT

    class << self
      def analyze_screenshot(image_data)
        return default_analysis unless image_data

        # Convert image to base64 if needed
        base64_image = if image_data.is_a?(String) && image_data.start_with?('data:')
                        image_data
                      else
                        "data:image/jpeg;base64,#{Base64.encode64(image_data)}"
                      end

        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
              {
                role: "user",
                content: [
                  {
                    type: "text",
                    text: SYSTEM_PROMPT
                  },
                  {
                    type: "image_url",
                    image_url: {
                      url: base64_image
                    }
                  }
                ]
              }
            ],
            temperature: 0.1,
            response_format: { type: "json_object" }
          }
        )

        result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
        
        # Validate and clean up the result
        validate_and_clean_result(result)
        
      rescue StandardError => e
        Rails.logger.error "Garmin screenshot analysis error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        default_analysis
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: Rails.application.credentials.dig(:openai, :api_key),
          log_errors: Rails.env.development?
        )
      end

      def validate_and_clean_result(result)
        # Ensure required fields exist
        result[:is_garmin_screenshot] ||= false
        result[:confidence_score] ||= 0
        result[:detected_metrics] ||= []
        result[:garmin_data] ||= {}
        
        # Only process further if it's actually a Garmin screenshot
        return result unless result[:is_garmin_screenshot]

        # Validate activity type
        valid_types = %w[running cycling strength swimming walking hiking yoga other]
        result[:activity_type] = 'other' unless valid_types.include?(result[:activity_type])

        # Ensure numeric fields are properly formatted
        result[:duration_minutes] = result[:duration_minutes].to_i if result[:duration_minutes]
        result[:distance_km] = result[:distance_km].to_f if result[:distance_km]
        result[:calories_burned] = result[:calories_burned].to_i if result[:calories_burned]
        result[:average_heart_rate] = result[:average_heart_rate].to_i if result[:average_heart_rate]
        result[:max_heart_rate] = result[:max_heart_rate].to_i if result[:max_heart_rate]

        # Parse activity date
        if result[:activity_date].present?
          begin
            result[:activity_date] = Time.parse(result[:activity_date])
          rescue
            result[:activity_date] = Time.current
          end
        else
          result[:activity_date] = Time.current
        end

        result
      end

      def default_analysis
        {
          is_garmin_screenshot: false,
          activity_type: nil,
          duration_minutes: nil,
          distance_km: nil,
          calories_burned: nil,
          average_heart_rate: nil,
          max_heart_rate: nil,
          average_pace: nil,
          activity_date: nil,
          confidence_score: 0,
          detected_metrics: [],
          notes: "Не удалось проанализировать изображение",
          garmin_data: {}
        }
      end
    end
  end
end
module Ai
  class DailyHealthAnalyzer
    SYSTEM_PROMPT = <<~PROMPT
      Ты — AI-аналитик здоровья, который анализирует дневные данные пользователя о питании и активности.

      Твоя задача — проанализировать весь день и дать персональные рекомендации, оценки и выводы.

      Ты получишь данные о:
      - Питании: калории, белки, жиры, углеводы, приёмы пищи
      - Активности: тренировки, время, калории сожжено, тип активности
      - Общая информация: цели пользователя (если есть)

      Анализируй по следующим критериям:

      1. **Баланс калорий**: потреблено vs сожжено
      2. **Качество питания**: соотношение БЖУ, регулярность приёмов пищи
      3. **Физическая активность**: достаточность, интенсивность, разнообразие
      4. **Общее состояние**: энергетический баланс, восстановление

      Верни ТОЛЬКО JSON в формате:
      {
        "overall_score": от_1_до_10,
        "calorie_balance": {
          "consumed": число_потреблённых_калорий,
          "burned": число_сожжённых_калорий,
          "balance": разница_(consumed_minus_burned),
          "status": "deficit|surplus|balanced",
          "recommendation": "краткая_рекомендация"
        },
        "nutrition_analysis": {
          "score": от_1_до_10,
          "protein_adequate": true|false,
          "meal_frequency": "good|poor|excellent",
          "suggestions": ["список", "рекомендаций", "по", "питанию"]
        },
        "activity_analysis": {
          "score": от_1_до_10,
          "total_duration_minutes": общее_время_активности,
          "activity_variety": "low|medium|high",
          "intensity": "light|moderate|vigorous",
          "suggestions": ["список", "рекомендаций", "по", "активности"]
        },
        "achievements": ["список", "достижений", "за", "день"],
        "warnings": ["список", "предупреждений", "или", "проблем"],
        "tomorrow_recommendations": ["рекомендации", "на", "завтра"],
        "motivation_message": "короткое_мотивационное_сообщение"
      }

      Правила анализа:
      - overall_score: общая оценка дня (1-4 плохо, 5-6 средне, 7-8 хорошо, 9-10 отлично)
      - calorie_balance status: "balanced" если разница ±200 ккал, "deficit" если меньше -200, "surplus" если больше +200
      - Учитывай индивидуальные особенности: возраст, пол, активность
      - Будь конструктивным и мотивирующим
      - Рекомендации должны быть конкретными и действенными

      Примеры анализа:

      **Хороший день:**
      - Потреблено 2000 ккал, сожжено 2200 → дефицит 200 ккал (хорошо для похудения)
      - 3-4 приёма пищи, достаточно белка
      - 60+ минут активности
      - overall_score: 8/10

      **Проблемный день:**
      - Потреблено 3000 ккал, сожжено 300 ккал → избыток 2700 ккал
      - 1-2 приёма пищи, мало белка
      - Нет активности
      - overall_score: 3/10

      Адаптируй анализ под тип активности:
      - Кардио (бег, велосипед) → упор на восстановление, углеводы
      - Силовая → упор на белок, отдых
      - Отсутствие активности → мотивация к движению

      Будь персональным коучем по здоровью!
    PROMPT

    class << self
      def analyze_day(user, date = Date.current)
        # Collect nutrition data for the day
        nutrition_data = collect_nutrition_data(user, date)
        
        # Collect activity data for the day
        activity_data = collect_activity_data(user, date)
        
        # Prepare context for AI
        context = build_analysis_context(nutrition_data, activity_data, user)
        
        # Get AI analysis
        ai_analysis = get_ai_analysis(context)
        
        # Enhance with calculated metrics
        enhance_analysis(ai_analysis, nutrition_data, activity_data)
        
      rescue StandardError => e
        Rails.logger.error "Daily health analysis error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        default_analysis
      end

      private

      def collect_nutrition_data(user, date)
        nutrition_entries = user.nutrition_entries.where(
          recorded_at: date.beginning_of_day..date.end_of_day
        )

        {
          total_calories: nutrition_entries.sum(:calories),
          total_protein: nutrition_entries.sum(:protein),
          total_fat: nutrition_entries.sum(:fat),
          total_carbs: nutrition_entries.sum(:carbs),
          meal_count: nutrition_entries.count,
          meals_by_type: nutrition_entries.group(:meal_type).count,
          entries: nutrition_entries.map do |entry|
            {
              meal_type: entry.meal_type,
              calories: entry.calories,
              protein: entry.protein,
              fat: entry.fat,
              carbs: entry.carbs,
              time: entry.recorded_at
            }
          end
        }
      end

      def collect_activity_data(user, date)
        activity_entries = user.activity_entries.active.where(
          activity_date: date.beginning_of_day..date.end_of_day
        )

        {
          total_duration: activity_entries.sum(:duration_minutes),
          total_calories_burned: activity_entries.sum(:calories_burned),
          total_distance: activity_entries.sum(:distance_km),
          activity_count: activity_entries.count,
          activities_by_type: activity_entries.group(:activity_type).count,
          entries: activity_entries.map do |entry|
            {
              activity_type: entry.activity_type,
              duration_minutes: entry.duration_minutes,
              calories_burned: entry.calories_burned,
              distance_km: entry.distance_km,
              average_heart_rate: entry.average_heart_rate,
              time: entry.activity_date
            }
          end
        }
      end

      def build_analysis_context(nutrition_data, activity_data, user)
        {
          user_info: {
            timezone: user.timezone,
            language: user.language
          },
          nutrition: nutrition_data,
          activity: activity_data,
          analysis_date: Date.current.strftime('%Y-%m-%d')
        }
      end

      def get_ai_analysis(context)
        response = client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: "Проанализируй дневные данные пользователя:\n\n#{context.to_json}" }
            ],
            temperature: 0.2,
            response_format: { type: "json_object" }
          }
        )

        JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
      end

      def enhance_analysis(analysis, nutrition_data, activity_data)
        # Update with actual calculated values
        analysis[:calorie_balance][:consumed] = nutrition_data[:total_calories].to_i
        analysis[:calorie_balance][:burned] = activity_data[:total_calories_burned].to_i
        analysis[:calorie_balance][:balance] = nutrition_data[:total_calories].to_i - activity_data[:total_calories_burned].to_i
        
        analysis[:activity_analysis][:total_duration_minutes] = activity_data[:total_duration].to_i
        
        # Add summary stats
        analysis[:summary] = {
          total_meals: nutrition_data[:meal_count],
          total_workouts: activity_data[:activity_count],
          dominant_activity: activity_data[:activities_by_type].max_by(&:last)&.first || 'none',
          nutrition_quality: calculate_nutrition_quality(nutrition_data)
        }
        
        analysis
      end

      def calculate_nutrition_quality(nutrition_data)
        return 'poor' if nutrition_data[:meal_count] == 0
        
        protein_ratio = nutrition_data[:total_protein] * 4 / [nutrition_data[:total_calories], 1].max
        
        case
        when nutrition_data[:meal_count] >= 3 && protein_ratio >= 0.15
          'excellent'
        when nutrition_data[:meal_count] >= 2 && protein_ratio >= 0.10
          'good'
        else
          'fair'
        end
      end

      def client
        @client ||= OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          log_errors: Rails.env.development?
        )
      end

      def default_analysis
        {
          overall_score: 5,
          calorie_balance: {
            consumed: 0,
            burned: 0,
            balance: 0,
            status: "balanced",
            recommendation: "Добавьте данные о питании и активности для анализа"
          },
          nutrition_analysis: {
            score: 5,
            protein_adequate: false,
            meal_frequency: "poor",
            suggestions: ["Начните отслеживать приёмы пищи"]
          },
          activity_analysis: {
            score: 5,
            total_duration_minutes: 0,
            activity_variety: "low",
            intensity: "light",
            suggestions: ["Добавьте хотя бы 30 минут активности в день"]
          },
          achievements: [],
          warnings: ["Недостаточно данных для полного анализа"],
          tomorrow_recommendations: ["Отслеживайте питание и активность завтра"],
          motivation_message: "Каждый день — новая возможность стать здоровее! 💪"
        }
      end
    end
  end
end
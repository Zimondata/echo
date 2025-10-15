class Ai::PlanGenerator
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :user
  attribute :idea_content, :string
  attribute :context, :string, default: ""
  attribute :time_preference, :string, default: "flexible"
  
  def self.call(user:, idea_content:, context: "", time_preference: "flexible")
    new(
      user: user,
      idea_content: idea_content,
      context: context,
      time_preference: time_preference
    ).generate_plan
  end

  def generate_plan
    return fallback_plan if idea_content.blank?

    client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_api_key)
    
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: build_messages,
        max_tokens: 1000,
        temperature: 0.7
      }
    )

    parse_response(response.dig("choices", 0, "message", "content"))
  rescue StandardError => e
    Rails.logger.error "AI Plan Generator error: #{e.message}"
    fallback_plan
  end

  private

  def build_messages
    [
      {
        role: "system",
        content: system_prompt
      },
      {
        role: "user",
        content: user_prompt
      }
    ]
  end

  def system_prompt
    <<~PROMPT
      Ты эксперт по планированию и продуктивности. Твоя задача - превратить идеи пользователя в конкретные, выполнимые планы.

      Правила:
      1. Анализируй идею и создавай пошаговый план реализации
      2. Оценивай примерное время выполнения каждой задачи
      3. Определяй приоритеты (высокий, средний, низкий)
      4. Предлагай оптимальное время для выполнения
      5. Учитывай контекст и предпочтения пользователя

      Ответ должен быть в JSON формате:
      {
        "plan_title": "Краткое название плана",
        "summary": "2-3 предложения о плане",
        "estimated_duration": "общее время в часах или днях",
        "priority": "high|medium|low",
        "tasks": [
          {
            "title": "Название задачи",
            "description": "Подробное описание",
            "estimated_time": "время в минутах",
            "priority": "high|medium|low",
            "suggested_time": "утром|днем|вечером|любое время",
            "category": "work|life|health|ideas|projects"
          }
        ],
        "tips": ["полезный совет 1", "полезный совет 2"],
        "potential_obstacles": ["возможная проблема 1", "возможная проблема 2"],
        "success_metrics": ["как измерить успех"]
      }

      Пиши на русском языке естественно и дружелюбно.
    PROMPT
  end

  def user_prompt
    prompt = <<~PROMPT
      Идея пользователя: "#{idea_content}"
      
      Дополнительный контекст: #{context.present? ? context : "Нет"}
      Предпочтения по времени: #{time_preference}
      
      Создай детальный план реализации этой идеи с конкретными шагами и временными рамками.
    PROMPT

    # Добавляем контекст о текущих записях пользователя
    if user&.entries&.recent&.limit(5)&.any?
      recent_themes = extract_recent_themes
      prompt += "\n\nПоследние темы пользователя: #{recent_themes.join(', ')}"
    end

    prompt
  end

  def extract_recent_themes
    return [] unless user

    user.entries.recent.limit(10).pluck(:content)
        .map { |content| extract_keywords(content) }
        .flatten
        .uniq
        .first(5)
  end

  def extract_keywords(text)
    # Простое извлечение ключевых слов (в реальности можно использовать NLP)
    stopwords = %w[я мне мой моя мое в на за с по до от при о об для к у из без]
    words = text.downcase.split(/\W+/).reject { |w| w.length < 3 || stopwords.include?(w) }
    words.first(3)
  end

  def parse_response(content)
    return fallback_plan if content.blank?

    # Извлекаем JSON из ответа
    json_match = content.match(/\{.*\}/m)
    return fallback_plan unless json_match

    plan_data = JSON.parse(json_match[0])
    
    # Валидируем структуру
    validate_plan_structure(plan_data)
    
    plan_data.with_indifferent_access
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing error in PlanGenerator: #{e.message}"
    fallback_plan
  end

  def validate_plan_structure(plan)
    required_fields = %w[plan_title summary tasks]
    missing_fields = required_fields - plan.keys
    
    if missing_fields.any?
      Rails.logger.warn "Missing required fields in plan: #{missing_fields}"
    end

    # Обеспечиваем, что у каждой задачи есть базовые поля
    plan["tasks"]&.each_with_index do |task, index|
      task["title"] ||= "Задача #{index + 1}"
      task["category"] ||= "ideas"
      task["priority"] ||= "medium"
      task["estimated_time"] ||= "30"
    end

    plan
  end

  def fallback_plan
    {
      plan_title: "План реализации идеи",
      summary: "Создан базовый план для реализации вашей идеи. Рекомендуется разбить на конкретные шаги.",
      estimated_duration: "1-2 дня",
      priority: "medium",
      tasks: [
        {
          title: "Исследование и планирование",
          description: "Детальное изучение идеи и составление плана действий",
          estimated_time: "60",
          priority: "high",
          suggested_time: "утром",
          category: "ideas"
        },
        {
          title: "Первые шаги реализации",
          description: "Начало практической работы над идеей",
          estimated_time: "90",
          priority: "medium",
          suggested_time: "днем",
          category: "projects"
        }
      ],
      tips: [
        "Начните с малого - не пытайтесь сделать всё сразу",
        "Разбивайте большие задачи на более мелкие шаги"
      ],
      potential_obstacles: [
        "Недостаток времени",
        "Отсутствие мотивации"
      ],
      success_metrics: [
        "Завершение всех запланированных задач",
        "Получение конкретного результата"
      ]
    }.with_indifferent_access
  end
end
class Ai::QuestGeneratorService
  def initialize(entry)
    @entry = entry
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def generate_quest
    return false unless @entry.entry_type == 'idea'
    return false if @entry.quest_generated?

    quest_data = analyze_for_quest
    return false unless quest_data

    quest = Quest.create!(
      entry: @entry,
      user: @entry.user,
      title: quest_data[:title],
      description: quest_data[:description],
      steps: build_quest_steps(quest_data),
      priority: quest_data[:priority] || 'medium',
      status: 'active'
    )

    @entry.update!(quest_generated: true)
    quest
  rescue => e
    Rails.logger.error "Quest generation failed: #{e.message}"
    false
  end

  private

  def analyze_for_quest
    prompt = build_quest_analysis_prompt
    response = call_openai(prompt)
    parse_json_response(response)
  end

  def build_quest_analysis_prompt
    research_context = @entry.research_data.present? ? 
      "Доступные исследования: #{@entry.research_data.to_json}" : 
      "Исследования не проводились"

    """
    Создай квест для реализации бизнес-идеи:

    Идея: #{@entry.content}
    #{research_context}

    Создай структурированный план действий (квест) который поможет пользователю:
    1. Валидировать идею
    2. Найти первых клиентов
    3. Создать MVP
    4. Запустить продукт

    Квест должен включать:
    - Название квеста
    - Описание (зачем этот квест)
    - 8-12 конкретных задач с чек-листом
    - Приоритет (high/medium/low)
    - Примерные сроки выполнения

    Каждая задача должна быть:
    - Конкретной и измеримой
    - Выполнимой за 1-3 дня
    - Направленной на получение результата

    Ответь в JSON формате:
    {
      "title": "Название квеста",
      "description": "Зачем этот квест нужен",
      "priority": "high/medium/low",
      "estimated_duration": "примерные сроки",
      "checklist": [
        {
          "id": 1,
          "task": "Конкретная задача",
          "description": "Подробное описание что делать",
          "priority": "high/medium/low",
          "estimated_time": "1-3 дня",
          "success_criteria": "Критерии успешного выполнения"
        }
      ],
      "goals": ["цель 1", "цель 2"],
      "expected_outcomes": ["результат 1", "результат 2"]
    }
    """
  end

  def build_quest_steps(quest_data)
    {
      checklist: quest_data[:checklist]&.map&.with_index do |task, index|
        {
          id: index + 1,
          task: task[:task],
          description: task[:description],
          priority: task[:priority] || 'medium',
          estimated_time: task[:estimated_time],
          success_criteria: task[:success_criteria],
          completed: false,
          completed_at: nil
        }
      end || [],
      goals: quest_data[:goals] || [],
      expected_outcomes: quest_data[:expected_outcomes] || [],
      estimated_duration: quest_data[:estimated_duration],
      progress: {
        completed_tasks: 0,
        total_tasks: quest_data[:checklist]&.length || 0,
        completion_percentage: 0
      }
    }
  end

  def call_openai(prompt)
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "Ты эксперт по созданию бизнес-планов и квестов для валидации идей. Создавай практичные, выполнимые задачи. Отвечай только в JSON формате на русском языке."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.8,
        max_tokens: 2000
      }
    )
    
    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI API call failed: #{e.message}"
    nil
  end

  def parse_json_response(response)
    return nil unless response
    
    parsed = JSON.parse(response, symbolize_names: true)
    
    # Валидация обязательных полей
    required_fields = [:title, :description, :checklist]
    return nil unless required_fields.all? { |field| parsed[field].present? }
    
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse JSON response: #{e.message}"
    Rails.logger.error "Response was: #{response}"
    nil
  end
end
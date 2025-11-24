class Ai::IdeaResearchService
  include Rails.application.routes.url_helpers
  
  def initialize(entry)
    @entry = entry
    @client = OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :api_key))
  end

  def perform_research
    return false unless @entry.entry_type == 'idea'

    research_data = {
      icp_analysis: analyze_target_audience,
      market_research: research_market,
      go_to_market: generate_gtm_strategy,
      technical_feasibility: analyze_feasibility,
      competition_analysis: analyze_competition,
      generated_at: Time.current
    }

    @entry.update!(research_data: research_data)
    research_data
  rescue => e
    Rails.logger.error "Idea research failed: #{e.message}"
    false
  end

  private

  def analyze_target_audience
    prompt = build_icp_prompt
    response = call_openai(prompt)
    parse_json_response(response, fallback: { target_audience: "Не определена", pain_points: [], market_size: "Неизвестно" })
  end

  def research_market
    prompt = build_market_research_prompt
    response = call_openai(prompt)
    parse_json_response(response, fallback: { market_trends: [], opportunities: [], risks: [] })
  end

  def generate_gtm_strategy
    prompt = build_gtm_prompt
    response = call_openai(prompt)
    parse_json_response(response, fallback: { channels: [], pricing: "Не определено", mvp_features: [] })
  end

  def analyze_feasibility
    prompt = build_feasibility_prompt
    response = call_openai(prompt)
    parse_json_response(response, fallback: { complexity: "medium", required_skills: [], timeline: "Не определено" })
  end

  def analyze_competition
    prompt = build_competition_prompt
    response = call_openai(prompt)
    parse_json_response(response, fallback: { direct_competitors: [], indirect_competitors: [], competitive_advantage: [] })
  end

  def build_icp_prompt
    """
    Проанализируй бизнес-идею и определи целевую аудиторию (ICP):

    Идея: #{@entry.content}

    Определи:
    1. Основную целевую аудиторию (демография, психография)
    2. Ключевые боли и потребности этой аудитории
    3. Примерный размер рынка
    4. Готовность платить за решение

    Ответь в JSON формате:
    {
      "target_audience": "описание ЦА",
      "demographics": ["возраст", "доход", "локация"],
      "pain_points": ["боль 1", "боль 2", "боль 3"],
      "market_size": "оценка размера рынка",
      "willingness_to_pay": "готовность платить"
    }
    """
  end

  def build_market_research_prompt
    """
    Проведи исследование рынка для идеи:

    Идея: #{@entry.content}

    Проанализируй:
    1. Текущие тренды рынка
    2. Возможности для роста
    3. Основные риски и барьеры входа

    Ответь в JSON формате:
    {
      "market_trends": ["тренд 1", "тренд 2"],
      "opportunities": ["возможность 1", "возможность 2"],
      "risks": ["риск 1", "риск 2"],
      "market_maturity": "развивающийся/зрелый/новый"
    }
    """
  end

  def build_gtm_prompt
    """
    Создай Go-to-Market стратегию для идеи:

    Идея: #{@entry.content}

    Определи:
    1. Эффективные каналы привлечения клиентов
    2. Стратегию ценообразования
    3. Ключевые функции MVP
    4. Метрики успеха для измерения

    Ответь в JSON формате:
    {
      "channels": ["канал 1", "канал 2"],
      "pricing": "стратегия ценообразования",
      "mvp_features": ["функция 1", "функция 2"],
      "success_metrics": ["метрика 1", "метрика 2"]
    }
    """
  end

  def build_feasibility_prompt
    """
    Оцени техническую и бизнес осуществимость идеи:

    Идея: #{@entry.content}

    Оцени:
    1. Сложность реализации (low/medium/high)
    2. Необходимые навыки и ресурсы
    3. Примерные временные рамки
    4. Стартовые инвестиции

    Ответь в JSON формате:
    {
      "complexity": "low/medium/high",
      "required_skills": ["навык 1", "навык 2"],
      "timeline": "временные рамки",
      "initial_investment": "оценка инвестиций"
    }
    """
  end

  def build_competition_prompt
    """
    Проанализируй конкурентную среду для идеи:

    Идея: #{@entry.content}

    Найди:
    1. Прямых конкурентов
    2. Косвенных конкурентов
    3. Конкурентные преимущества для данной идеи

    Ответь в JSON формате:
    {
      "direct_competitors": ["конкурент 1", "конкурент 2"],
      "indirect_competitors": ["косвенный 1", "косвенный 2"],
      "competitive_advantage": ["преимущество 1", "преимущество 2"]
    }
    """
  end

  def call_openai(prompt)
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "Ты эксперт по бизнес-анализу и исследованию рынка. Отвечай только в JSON формате на русском языке."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 1500
      }
    )
    
    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI API call failed: #{e.message}"
    nil
  end

  def parse_json_response(response, fallback: {})
    return fallback unless response
    
    JSON.parse(response)
  rescue JSON::ParserError
    Rails.logger.error "Failed to parse JSON response: #{response}"
    fallback
  end
end
class Ai::InsightGenerator
  include ActiveSupport::Benchmarkable

  SYSTEM_PROMPTS = {
    daily_summary: "You are an AI assistant analyzing a user's daily entries (diary, ideas, plans). Provide a concise, insightful summary in Russian highlighting key themes, mood patterns, and productivity insights.",
    
    weekly_digest: "You are analyzing a week's worth of personal entries. Create a comprehensive digest in Russian that includes achievements, patterns, growth areas, and suggestions for the upcoming week.",
    
    trend_analysis: "You are analyzing long-term patterns in personal entries. Identify trends, behavioral patterns, and provide actionable insights for personal development in Russian.",
    
    productivity_insight: "You analyze productivity patterns from personal entries. Focus on work habits, efficiency patterns, and provide specific recommendations for improvement in Russian."
  }.freeze

  def self.call(content:, insight_type:, context: {})
    new(content, insight_type, context).generate
  end

  def initialize(content, insight_type, context = {})
    @content = content
    @insight_type = insight_type
    @context = context
    @client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_api_key)
  end

  def generate
    benchmark "AI Insight Generation (#{@insight_type})" do
      case @insight_type
      when 'daily_summary'
        generate_daily_summary
      when 'weekly_digest'
        generate_weekly_digest
      when 'trend_analysis'
        generate_trend_analysis
      when 'productivity_insight'
        generate_productivity_insight
      else
        fallback_insight
      end
    end
  rescue StandardError => e
    Rails.logger.error "AI Insight Generation failed: #{e.message}"
    fallback_insight
  end

  private

  def generate_daily_summary
    prompt = build_daily_summary_prompt
    response = call_openai(prompt)
    
    parse_daily_summary_response(response)
  end

  def generate_weekly_digest
    prompt = build_weekly_digest_prompt
    response = call_openai(prompt)
    
    parse_weekly_digest_response(response)
  end

  def generate_trend_analysis
    prompt = build_trend_analysis_prompt
    response = call_openai(prompt)
    
    parse_trend_analysis_response(response)
  end

  def generate_productivity_insight
    prompt = build_productivity_prompt
    response = call_openai(prompt)
    
    parse_productivity_response(response)
  end

  def build_daily_summary_prompt
    stats = @context[:stats] || {}
    
    <<~PROMPT
      Проанализируй дневные записи пользователя и создай краткое резюме дня.

      СТАТИСТИКА ДНЯ:
      - Всего записей: #{@context[:total_entries] || 0}
      - По типам: #{stats[:by_type]&.to_json || 'нет данных'}
      - По категориям: #{stats[:categories]&.to_json || 'нет данных'}

      ЗАПИСИ:
      #{@content}

      Создай JSON ответ со следующей структурой:
      {
        "summary": "Краткое резюме дня (2-3 предложения)",
        "highlights": ["ключевое событие 1", "ключевое событие 2"],
        "mood": {"score": 0-10, "description": "описание настроения"},
        "themes": ["основная тема 1", "основная тема 2"]
      }

      Пиши на русском языке, будь краток и инсайтфул.
    PROMPT
  end

  def build_weekly_digest_prompt
    stats = @context[:stats] || {}
    
    <<~PROMPT
      Проанализируй недельную активность пользователя и создай еженедельный дайджест.

      СТАТИСТИКА НЕДЕЛИ:
      - Всего записей: #{@context[:total_entries] || 0}
      - По дням: #{stats[:daily_breakdown]&.to_json || 'нет данных'}
      - Топ категории: #{stats[:top_categories]&.to_json || 'нет данных'}
      - Оценка продуктивности: #{stats[:productivity_score] || 'не рассчитана'}

      СОДЕРЖАНИЕ:
      #{@content}

      Создай JSON ответ со следующей структурой:
      {
        "digest": "Общий обзор недели (3-4 предложения)",
        "achievements": ["достижение 1", "достижение 2"],
        "insights": ["инсайт 1", "инсайт 2"],
        "goals": ["цель на следующую неделю 1", "цель на следующую неделю 2"]
      }

      Будь позитивен и мотивирующ. Пиши на русском языке.
    PROMPT
  end

  def build_trend_analysis_prompt
    <<~PROMPT
      Проанализируй долгосрочные тренды в личных записях пользователя.

      ПЕРИОД АНАЛИЗА: #{@context[:period]&.humanize || 'неизвестен'}
      КОЛИЧЕСТВО ЗАПИСЕЙ: #{@context[:entries_count] || 0}

      ДАННЫЕ ТРЕНДОВ:
      #{@content}

      Создай JSON ответ со следующей структурой:
      {
        "analysis": "Общий анализ трендов (4-5 предложений)",
        "patterns": ["выявленный паттерн 1", "выявленный паттерн 2"],
        "recommendations": ["рекомендация 1", "рекомендация 2"],
        "growth_areas": ["область для роста 1", "область для роста 2"]
      }

      Фокусируйся на практических инсайтах. Пиши на русском языке.
    PROMPT
  end

  def build_productivity_prompt
    metrics = @context[:metrics] || {}
    
    <<~PROMPT
      Проанализируй продуктивность пользователя на основе его записей.

      МЕТРИКИ ПРОДУКТИВНОСТИ:
      #{metrics.to_json}

      СОДЕРЖАНИЕ ЗАПИСЕЙ:
      #{@content}

      Создай JSON ответ со следующей структурой:
      {
        "insight": "Главный инсайт о продуктивности (3-4 предложения)",
        "suggestions": ["совет 1", "совет 2", "совет 3"],
        "focus_areas": ["область фокуса 1", "область фокуса 2"]
      }

      Давай конкретные, применимые советы. Пиши на русском языке.
    PROMPT
  end

  def call_openai(prompt)
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: SYSTEM_PROMPTS[@insight_type.to_sym]
          },
          {
            role: "user",
            content: prompt
          }
        ],
        max_tokens: 1000,
        temperature: 0.7
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue StandardError => e
    Rails.logger.error "OpenAI API call failed: #{e.message}"
    nil
  end

  def parse_daily_summary_response(response)
    return fallback_daily_summary if response.blank?
    
    JSON.parse(response).with_indifferent_access
  rescue JSON::ParserError
    Rails.logger.warn "Failed to parse AI response as JSON: #{response}"
    extract_summary_from_text(response)
  end

  def parse_weekly_digest_response(response)
    return fallback_weekly_digest if response.blank?
    
    JSON.parse(response).with_indifferent_access
  rescue JSON::ParserError
    extract_digest_from_text(response)
  end

  def parse_trend_analysis_response(response)
    return fallback_trend_analysis if response.blank?
    
    JSON.parse(response).with_indifferent_access
  rescue JSON::ParserError
    extract_trends_from_text(response)
  end

  def parse_productivity_response(response)
    return fallback_productivity_insight if response.blank?
    
    JSON.parse(response).with_indifferent_access
  rescue JSON::ParserError
    extract_productivity_from_text(response)
  end

  def fallback_insight
    case @insight_type
    when 'daily_summary'
      fallback_daily_summary
    when 'weekly_digest'
      fallback_weekly_digest
    when 'trend_analysis'
      fallback_trend_analysis
    when 'productivity_insight'
      fallback_productivity_insight
    else
      { summary: "Не удалось сгенерировать инсайт" }
    end
  end

  def fallback_daily_summary
    {
      summary: "Сегодня у вас было #{@context[:total_entries] || 0} записей. Продолжайте отслеживать свои мысли и планы!",
      highlights: ["Активная работа с записями"],
      mood: { score: 7, description: "Продуктивный день" },
      themes: ["Личностный рост", "Планирование"]
    }
  end

  def fallback_weekly_digest
    {
      digest: "На этой неделе вы создали #{@context[:total_entries] || 0} записей. Хорошая активность для саморефлексии!",
      achievements: ["Регулярное ведение записей", "Систематизация мыслей"],
      insights: ["Важность постоянства", "Ценность саморефлексии"],
      goals: ["Продолжать ведение записей", "Углублять анализ"]
    }
  end

  def fallback_trend_analysis
    {
      analysis: "За анализируемый период отмечается стабильная активность в ведении записей.",
      patterns: ["Регулярность записей", "Разнообразие тем"],
      recommendations: ["Развивать глубину анализа", "Добавлять больше планов"],
      growth_areas: ["Структурирование мыслей", "Долгосрочное планирование"]
    }
  end

  def fallback_productivity_insight
    {
      insight: "Ваша продуктивность показывает положительную динамику. Продолжайте в том же духе!",
      suggestions: ["Увеличьте долю планирующих записей", "Регулярно анализируйте результаты"],
      focus_areas: ["Планирование задач", "Отслеживание прогресса"]
    }
  end

  def extract_summary_from_text(text)
    {
      summary: text.truncate(300),
      highlights: [],
      mood: { score: 7, description: "Нейтральное" },
      themes: []
    }
  end

  def extract_digest_from_text(text)
    {
      digest: text.truncate(400),
      achievements: [],
      insights: [],
      goals: []
    }
  end

  def extract_trends_from_text(text)
    {
      analysis: text.truncate(400),
      patterns: [],
      recommendations: [],
      growth_areas: []
    }
  end

  def extract_productivity_from_text(text)
    {
      insight: text.truncate(300),
      suggestions: [],
      focus_areas: []
    }
  end

  def logger
    Rails.logger
  end
end
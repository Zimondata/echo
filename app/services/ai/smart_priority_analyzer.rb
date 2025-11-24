class Ai::SmartPriorityAnalyzer
  include Rails.application.routes.url_helpers
  
  def initialize(user)
    @user = user
    @client = OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :api_key))
  end

  def analyze_all_ideas
    ideas = @user.entries.ideas.where('created_at > ?', 6.months.ago)
    return if ideas.empty?

    results = []
    
    ideas.find_each do |idea|
      score = analyze_idea_priority(idea)
      update_idea_priority(idea, score)
      results << { idea: idea, score: score }
    end

    # Сортируем по общему приоритету
    results.sort_by { |r| -r[:score][:total_score] }
  end

  def analyze_idea_priority(idea)
    context = build_analysis_context(idea)
    
    # Мультифакторный анализ
    scores = {
      market_timing: analyze_market_timing(idea, context),
      innovation_level: analyze_innovation(idea, context),
      feasibility: analyze_feasibility(idea, context),
      competitive_advantage: analyze_competition(idea, context),
      resource_match: analyze_resource_fit(idea, context),
      trend_momentum: analyze_trends(idea, context),
      urgency_factor: analyze_urgency(idea, context)
    }

    # Взвешенный общий балл
    total_score = calculate_weighted_score(scores)
    
    {
      **scores,
      total_score: total_score,
      priority_level: determine_priority_level(total_score),
      recommendations: generate_recommendations(idea, scores),
      analysis_timestamp: Time.current
    }
  end

  private

  def build_analysis_context(idea)
    {
      user_context: build_user_context,
      idea_content: idea.content,
      creation_date: idea.created_at,
      existing_research: idea.research_data,
      related_ideas: find_related_ideas(idea),
      current_projects: get_user_projects,
      market_context: get_market_context
    }
  end

  def build_user_context
    recent_ideas = @user.entries.ideas.recent.limit(20)
    
    {
      expertise_areas: extract_expertise_areas(recent_ideas),
      focus_themes: extract_recurring_themes(recent_ideas),
      preferred_complexity: analyze_complexity_preference(recent_ideas),
      success_patterns: analyze_successful_patterns,
      available_time: estimate_available_time,
      risk_tolerance: estimate_risk_tolerance(recent_ideas)
    }
  end

  def analyze_market_timing(idea, context)
    prompt = build_market_timing_prompt(idea, context)
    response = call_openai(prompt)
    parse_score_response(response, fallback: 5.0)
  end

  def analyze_innovation(idea, context)
    prompt = build_innovation_prompt(idea, context)
    response = call_openai(prompt)
    parse_score_response(response, fallback: 5.0)
  end

  def analyze_feasibility(idea, context)
    prompt = build_feasibility_prompt(idea, context)
    response = call_openai(prompt)
    parse_score_response(response, fallback: 5.0)
  end

  def analyze_competition(idea, context)
    prompt = build_competition_prompt(idea, context)
    response = call_openai(prompt)
    parse_score_response(response, fallback: 5.0)
  end

  def analyze_resource_fit(idea, context)
    prompt = build_resource_fit_prompt(idea, context)
    response = call_openai(prompt)
    parse_score_response(response, fallback: 5.0)
  end

  def analyze_trends(idea, context)
    prompt = build_trends_prompt(idea, context)
    response = call_openai(prompt)
    parse_score_response(response, fallback: 5.0)
  end

  def analyze_urgency(idea, context)
    # Анализ временных факторов
    days_since_creation = (Time.current - idea.created_at) / 1.day
    
    base_urgency = case days_since_creation
    when 0..3 then 9.0    # Свежая идея - высокий приоритет
    when 4..14 then 7.0   # Недельная идея - средний приоритет  
    when 15..30 then 4.0  # Месячная идея - нужна переоценка
    else 2.0              # Старая идея - низкий приоритет
    end

    # Корректировка на основе контента
    urgency_boost = detect_urgency_keywords(idea.content)
    
    [base_urgency + urgency_boost, 10.0].min
  end

  def detect_urgency_keywords(content)
    urgent_keywords = [
      'срочно', 'быстро', 'сейчас', 'тренд', 'взрыв', 'бум', 
      'пока не поздно', 'пока другие не', 'окно возможностей',
      'hot', 'trending', 'viral', 'breaking'
    ]
    
    boost = 0
    urgent_keywords.each do |keyword|
      boost += 1.5 if content.downcase.include?(keyword.downcase)
    end
    
    [boost, 3.0].min # Максимум +3 балла за срочность
  end

  def calculate_weighted_score(scores)
    weights = {
      market_timing: 0.20,      # 20% - когда запускать
      innovation_level: 0.15,   # 15% - насколько уникально
      feasibility: 0.18,        # 18% - можем ли сделать
      competitive_advantage: 0.12, # 12% - конкурентные преимущества
      resource_match: 0.15,     # 15% - соответствие ресурсам
      trend_momentum: 0.10,     # 10% - трендовость
      urgency_factor: 0.10      # 10% - срочность
    }

    total = 0
    weights.each do |factor, weight|
      total += scores[factor].to_f * weight
    end

    total.round(2)
  end

  def determine_priority_level(score)
    case score
    when 8.0..10.0 then 'critical'   # 🔥 Критический
    when 6.5..7.9 then 'high'        # ⭐ Высокий  
    when 4.0..6.4 then 'medium'      # 💡 Средний
    when 2.0..3.9 then 'low'         # 📝 Низкий
    else 'archive'                   # 🗄️ Архив
    end
  end

  def generate_recommendations(idea, scores)
    recommendations = []

    # Рекомендации на основе анализа
    if scores[:market_timing] > 8.0
      recommendations << {
        type: 'timing',
        priority: 'high',
        message: '🔥 Идеальный момент для запуска! Рынок готов.',
        action: 'create_quest_immediately'
      }
    end

    if scores[:innovation_level] > 8.0 && scores[:competitive_advantage] > 7.0
      recommendations << {
        type: 'innovation',
        priority: 'high', 
        message: '💎 Уникальная идея с сильными преимуществами!',
        action: 'prioritize_development'
      }
    end

    if scores[:feasibility] < 4.0
      recommendations << {
        type: 'feasibility',
        priority: 'medium',
        message: '⚠️ Требуются дополнительные ресурсы или навыки',
        action: 'plan_skill_development'
      }
    end

    if scores[:urgency_factor] > 8.0
      recommendations << {
        type: 'urgency',
        priority: 'critical',
        message: '⏰ Временное окно сужается! Нужны быстрые действия.',
        action: 'immediate_action_required'
      }
    end

    recommendations
  end

  def update_idea_priority(idea, score_data)
    # Обновляем числовой приоритет (1-10)
    priority_number = score_data[:total_score].round
    
    # Обновляем метаданные идеи
    metadata = idea.metadata || {}
    metadata['ai_analysis'] = {
      priority_score: score_data[:total_score],
      priority_level: score_data[:priority_level],
      scores_breakdown: score_data.except(:recommendations, :analysis_timestamp),
      recommendations: score_data[:recommendations],
      last_analyzed: score_data[:analysis_timestamp],
      analyzer_version: '1.0'
    }

    idea.update!(
      idea_priority: score_data[:priority_level],
      priority: priority_number,
      metadata: metadata
    )
  end

  # AI Prompts для анализа
  def build_market_timing_prompt(idea, context)
    """
    Проанализируй рыночный тайминг для идеи:

    Идея: #{idea.content}
    Дата создания: #{idea.created_at.strftime('%d.%m.%Y')}
    
    Контекст пользователя: #{context[:user_context][:expertise_areas]}

    Оцени по шкале 1-10 насколько сейчас подходящий момент для реализации этой идеи:
    - Готовность рынка
    - Технологическая зрелость  
    - Конкурентная ситуация
    - Потребительский спрос
    - Экономические факторы

    Ответь ТОЛЬКО числом от 1 до 10 (например: 7.5)
    """
  end

  def build_innovation_prompt(idea, context)
    """
    Оцени уровень инновационности идеи:

    Идея: #{idea.content}
    Похожие идеи пользователя: #{context[:related_ideas]&.map(&:content)&.join(', ')}

    Оцени по шкале 1-10:
    - Новизна подхода
    - Уникальность решения
    - Потенциал изменить рынок
    - Технологическая инновационность

    Ответь ТОЛЬКО числом от 1 до 10 (например: 8.2)
    """
  end

  def build_feasibility_prompt(idea, context)
    """
    Оцени техническую и ресурсную осуществимость:

    Идея: #{idea.content}
    Экспертиза пользователя: #{context[:user_context][:expertise_areas]}
    Сложность предпочтений: #{context[:user_context][:preferred_complexity]}

    Оцени по шкале 1-10 возможность реализации:
    - Соответствие навыкам
    - Требуемые ресурсы
    - Временные затраты
    - Техническая сложность

    Ответь ТОЛЬКО числом от 1 до 10 (например: 6.8)
    """
  end

  def build_competition_prompt(idea, context)
    """
    Проанализируй конкурентные преимущества:

    Идея: #{idea.content}

    Оцени по шкале 1-10 конкурентный потенциал:
    - Барьеры входа для конкурентов
    - Уникальность ценностного предложения
    - Возможность защиты (патенты, know-how)
    - Сетевые эффекты

    Ответь ТОЛЬКО числом от 1 до 10 (например: 5.3)
    """
  end

  def build_resource_fit_prompt(idea, context)
    """
    Оцени соответствие идеи ресурсам пользователя:

    Идея: #{idea.content}
    Области экспертизы: #{context[:user_context][:expertise_areas]}
    Успешные паттерны: #{context[:user_context][:success_patterns]}

    Оцени по шкале 1-10 соответствие:
    - Экспертиза и навыки
    - Доступные ресурсы
    - Предыдущий опыт
    - Сеть контактов

    Ответь ТОЛЬКО числом от 1 до 10 (например: 7.1)
    """
  end

  def build_trends_prompt(idea, context)
    """
    Оцени трендовость и импульс идеи:

    Идея: #{idea.content}
    Текущая дата: #{Date.current.strftime('%d.%m.%Y')}

    Оцени по шкале 1-10 трендовый потенциал:
    - Соответствие текущим трендам
    - Растущий интерес к теме
    - Социальная значимость
    - Медийный потенциал

    Ответь ТОЛЬКО числом от 1 до 10 (например: 8.7)
    """
  end

  def call_openai(prompt)
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "Ты эксперт по анализу бизнес-идей и рыночных трендов. Отвечай ТОЛЬКО числом от 1 до 10 с одним знаком после запятой."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 50
      }
    )
    
    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI API call failed in SmartPriorityAnalyzer: #{e.message}"
    nil
  end

  def parse_score_response(response, fallback: 5.0)
    return fallback unless response
    
    # Извлекаем число из ответа
    score = response.scan(/\d+\.?\d*/).first&.to_f
    return fallback unless score
    
    # Ограничиваем диапазон 1-10
    [[score, 1.0].max, 10.0].min
  rescue
    fallback
  end

  # Вспомогательные методы для анализа контекста
  def extract_expertise_areas(ideas)
    # Анализируем темы идей для определения областей экспертизы
    themes = ideas.map(&:content).join(' ')
    
    tech_keywords = ['AI', 'ML', 'блокчейн', 'приложение', 'сайт', 'API', 'ИИ']
    business_keywords = ['бизнес', 'продажи', 'маркетинг', 'клиенты', 'доход']
    creative_keywords = ['дизайн', 'контент', 'креатив', 'видео', 'фото']
    
    areas = []
    areas << 'technology' if tech_keywords.any? { |k| themes.downcase.include?(k.downcase) }
    areas << 'business' if business_keywords.any? { |k| themes.downcase.include?(k.downcase) }
    areas << 'creative' if creative_keywords.any? { |k| themes.downcase.include?(k.downcase) }
    
    areas.any? ? areas : ['general']
  end

  def extract_recurring_themes(ideas)
    # Простой анализ повторяющихся тем
    words = ideas.map(&:content).join(' ').downcase.split
    word_frequency = words.each_with_object(Hash.new(0)) { |word, hash| hash[word] += 1 }
    
    # Возвращаем топ-5 самых частых слов (длиной больше 3 символов)
    word_frequency
      .select { |word, count| word.length > 3 && count > 1 }
      .sort_by { |word, count| -count }
      .first(5)
      .map(&:first)
  end

  def analyze_complexity_preference(ideas)
    # Простая эвристика на основе длины описаний идей
    avg_length = ideas.map { |i| i.content.length }.sum.to_f / ideas.count
    
    case avg_length
    when 0..50 then 'simple'
    when 51..150 then 'medium'
    else 'complex'
    end
  end

  def analyze_successful_patterns
    # Заглушка для анализа успешных паттернов
    # В будущем можно анализировать завершенные квесты, реализованные идеи
    []
  end

  def estimate_available_time
    # Простая эвристика на основе активности
    recent_activity = @user.entries.where('created_at > ?', 1.week.ago).count
    
    case recent_activity
    when 0..2 then 'low'
    when 3..10 then 'medium'  
    else 'high'
    end
  end

  def estimate_risk_tolerance(ideas)
    # Анализ рискованности идей пользователя
    risky_keywords = ['стартап', 'инвестиции', 'большие деньги', 'революция']
    safe_keywords = ['улучшение', 'оптимизация', 'небольшой', 'простой']
    
    content = ideas.map(&:content).join(' ').downcase
    
    risky_score = risky_keywords.count { |k| content.include?(k) }
    safe_score = safe_keywords.count { |k| content.include?(k) }
    
    if risky_score > safe_score
      'high'
    elsif safe_score > risky_score
      'low'
    else
      'medium'
    end
  end

  def find_related_ideas(idea)
    # Простой поиск похожих идей по ключевым словам
    keywords = idea.content.downcase.split.select { |w| w.length > 3 }
    return [] if keywords.empty?
    
    @user.entries.ideas
         .where.not(id: idea.id)
         .where('created_at > ?', 3.months.ago)
         .select { |i| keywords.any? { |k| i.content.downcase.include?(k) } }
         .first(3)
  end

  def get_user_projects
    # Заглушка для получения текущих проектов пользователя
    # В будущем можно интегрировать с GitHub, Trello, etc.
    []
  end

  def get_market_context
    # Заглушка для рыночного контекста
    # В будущем можно интегрировать с внешними API
    {
      current_trends: [],
      market_conditions: 'stable',
      economic_indicators: 'positive'
    }
  end
end
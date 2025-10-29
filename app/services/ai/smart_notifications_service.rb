class Ai::SmartNotificationsService
  def initialize(user)
    @user = user
  end

  def generate_notifications
    notifications = []
    
    # Анализируем идеи пользователя
    ideas = @user.entries.where(entry_type: 'idea').order(created_at: :desc)
    
    # 1. Идеи готовые к исследованию (только потенциально полезные)
    unresearched_ideas = ideas.where(research_data: nil).limit(20)
    ready_for_research = filter_research_worthy_ideas(unresearched_ideas)
    
    if ready_for_research.count >= 2
      notifications << {
        type: 'research_ready',
        priority: 'medium',
        title: "Готовы к исследованию",
        message: "У вас #{ready_for_research.count} перспективных идей готовы к AI-исследованию",
        action_url: "/ideas_dashboard",
        action_text: "Посмотреть",
        icon: "🔬"
      }
    end

    # 2. Высокоприоритетные идеи без квестов
    high_priority_ideas = ideas.select do |idea|
      ai_analysis = idea.metadata&.dig('ai_analysis')
      priority_level = ai_analysis&.dig('priority_level')
      priority_level == 'high' || priority_level == 'critical'
    end.reject(&:quest_generated?)

    if high_priority_ideas.any?
      notifications << {
        type: 'high_priority_without_quest',
        priority: 'high',
        title: "Высокий приоритет",
        message: "Идея '#{high_priority_ideas.first.content.truncate(50)}' имеет высокий приоритет - стоит создать квест",
        action_url: "/smart_priority/#{high_priority_ideas.first.id}/analysis",
        action_text: "Создать квест",
        icon: "🔥"
      }
    end

    # 3. Идеи требующие внимания (старые без анализа)
    old_unanalyzed = ideas.where('created_at < ?', 1.week.ago)
                          .select { |i| i.metadata&.dig('ai_analysis').blank? }

    if old_unanalyzed.count >= 5
      notifications << {
        type: 'old_unanalyzed',
        priority: 'low',
        title: "Требуют анализа",
        message: "#{old_unanalyzed.count} старых идей ещё не проанализированы AI",
        action_url: "/ideas_dashboard",
        action_text: "Запустить анализ",
        icon: "🧠"
      }
    end

    # 4. Похожие идеи (можно объединить)
    similar_ideas = find_similar_ideas(ideas)
    if similar_ideas.any?
      notifications << {
        type: 'similar_ideas',
        priority: 'low',
        title: "Похожие идеи",
        message: "Найдены похожие идеи - возможно, стоит их объединить",
        action_url: "/ideas",
        action_text: "Посмотреть",
        icon: "🔗"
      }
    end

    # 5. Позитивная мотивация
    completed_quests = @user.quests.where(status: 'completed').count
    if completed_quests > 0 && Time.current.hour.between?(9, 18)
      notifications << {
        type: 'motivation',
        priority: 'low',
        title: "Отличная работа!",
        message: "Вы завершили #{completed_quests} квест#{completed_quests > 1 ? 'а' : ''}. Время для новых идей?",
        action_url: "/ideas",
        action_text: "К идеям",
        icon: "🎉"
      }
    end

    # Сортируем по приоритету
    priority_order = { 'high' => 3, 'medium' => 2, 'low' => 1 }
    notifications.sort_by { |n| -priority_order[n[:priority]] }
  end

  def get_weekly_insights
    ideas = @user.entries.where(entry_type: 'idea')
    week_ideas = ideas.where('created_at >= ?', 1.week.ago)
    
    insights = {
      new_ideas_count: week_ideas.count,
      researched_count: week_ideas.count { |i| i.research_data.present? },
      quests_created: @user.quests.where('created_at >= ?', 1.week.ago).count,
      top_priority_idea: get_top_priority_idea(week_ideas),
      productivity_trend: calculate_productivity_trend
    }

    insights
  end

  private

  def filter_research_worthy_ideas(ideas)
    # Фильтруем идеи по критериям исследовательского потенциала
    research_worthy = ideas.select do |idea|
      is_research_worthy?(idea)
    end
    
    research_worthy
  end

  def is_research_worthy?(idea)
    content = idea.content.downcase
    
    # Критерии исключения (НЕ стоит исследовать)
    exclude_patterns = [
      # Личные заметки и рефлексии
      /запись.*(дневник|мысли|чувства|настроение)/,
      /сегодня.*(был|была|думал|чувствовал)/,
      /(плохо|хорошо|устал|болит)/,
      
      # Простые планы и задачи
      /нужно.*(купить|сделать|не забыть|позвонить)/,
      /(завтра|сегодня|вчера).*(встреча|дела|планы)/,
      /список.*(дел|покупок|задач)/,
      
      # Общие мысли без конкретики
      /^(интересно|хочется|надо бы|можно было бы).{0,30}$/,
      /^(вообще|кстати|наверное).{0,50}$/,
      
      # Технические заметки
      /(баг|ошибка|не работает|исправить)/,
      /тестирование|дебаг|логи/
    ]
    
    # Если попадает под исключение - не исследуем
    return false if exclude_patterns.any? { |pattern| content.match?(pattern) }
    
    # Критерии включения (СТОИТ исследовать)
    include_patterns = [
      # Бизнес-идеи и проекты
      /(проект|стартап|бизнес|приложение|сервис|платформа)/,
      /(монетизация|доход|продажи|клиенты|пользователи)/,
      /(mvp|прототип|тестирование гипотез)/,
      
      # Инновации и технологии
      /(ai|ии|искусственный интеллект|машинное обучение)/,
      /(автоматизация|оптимизация|улучшение процесса)/,
      /(новая функция|фича|возможность)/,
      
      # Исследовательские вопросы
      /(исследование|анализ|изучение|разработка)/,
      /(как.*(работает|устроен|влияет|можно улучшить))/,
      /(почему.*(происходит|нужно|важно))/,
      
      # Продуктовые идеи
      /(пользователи|интерфейс|ux|ui|дизайн)/,
      /(функциональность|возможности|решение)/,
      /(проблема|потребность|боль пользователей)/,
      
      # Стратегические идеи
      /(стратегия|развитие|направление|тренд)/,
      /(рынок|конкуренты|аналоги|позиционирование)/,
      /(масштабирование|рост|экспансия)/
    ]
    
    # Проверяем длину - слишком короткие идеи обычно не информативны
    return false if content.length < 20
    
    # Проверяем наличие ключевых слов
    has_research_keywords = include_patterns.any? { |pattern| content.match?(pattern) }
    
    # Дополнительная проверка на сложность идеи
    complexity_indicators = [
      content.include?('как') && content.include?('?'),
      content.include?('почему') && content.include?('?'), 
      content.split(/[.!?]/).length > 2, # Несколько предложений
      content.match?(/\b(система|алгоритм|методика|подход|концепция)\b/),
      content.match?(/\b(интеграция|внедрение|реализация|разработка)\b/)
    ]
    
    complexity_score = complexity_indicators.count(true)
    
    # Идея достойна исследования если:
    # 1. Есть ключевые слова ИЛИ высокая сложность (3+ индикатора)
    # 2. И не попадает в исключения
    has_research_keywords || complexity_score >= 3
  end

  def find_similar_ideas(ideas)
    # Простой алгоритм поиска похожих идей по ключевым словам
    similar_groups = []
    processed = Set.new

    ideas.each do |idea1|
      next if processed.include?(idea1.id)
      
      similar = ideas.select do |idea2|
        next if idea1.id == idea2.id || processed.include?(idea2.id)
        similarity_score(idea1.content, idea2.content) > 0.6
      end

      if similar.any?
        similar_groups << [idea1] + similar
        processed.add(idea1.id)
        similar.each { |s| processed.add(s.id) }
      end
    end

    similar_groups
  end

  def similarity_score(text1, text2)
    # Простая оценка похожести по общим словам
    words1 = text1.downcase.split(/\W+/).reject(&:empty?)
    words2 = text2.downcase.split(/\W+/).reject(&:empty?)
    
    return 0 if words1.empty? || words2.empty?
    
    common_words = (words1 & words2).size
    total_words = (words1 + words2).uniq.size
    
    common_words.to_f / total_words
  end

  def get_top_priority_idea(ideas)
    ideas.max_by do |idea|
      ai_analysis = idea.metadata&.dig('ai_analysis')
      ai_analysis&.dig('priority_score') || 0
    end
  end

  def calculate_productivity_trend
    # Анализ продуктивности за последние недели
    current_week = @user.entries.where('created_at >= ?', 1.week.ago).count
    previous_week = @user.entries.where(created_at: 2.weeks.ago..1.week.ago).count
    
    return 'stable' if previous_week == 0
    
    change = ((current_week - previous_week).to_f / previous_week * 100).round
    
    case change
    when 20..Float::INFINITY then 'growing'
    when -20..20 then 'stable'  
    else 'declining'
    end
  end
end
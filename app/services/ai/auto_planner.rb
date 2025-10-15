class Ai::AutoPlanner
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :user
  attribute :trigger_type, :string, default: "manual" # manual, scheduled, context_based
  attribute :planning_horizon, :string, default: "daily" # daily, weekly
  attribute :options, default: -> { {} }
  
  def self.generate_daily_plan(user:, options: {})
    new(
      user: user,
      trigger_type: "manual",
      planning_horizon: "daily",
      options: options
    ).generate_plan
  end

  def self.generate_weekly_plan(user:, options: {})
    new(
      user: user,
      trigger_type: "manual", 
      planning_horizon: "weekly",
      options: options
    ).generate_plan
  end

  def self.suggest_next_actions(user:, options: {})
    new(
      user: user,
      trigger_type: "context_based",
      planning_horizon: "immediate",
      options: options
    ).suggest_actions
  end

  def generate_plan
    return fallback_plan unless user

    context = analyze_current_context
    existing_tasks = gather_existing_tasks
    
    case planning_horizon
    when "daily"
      generate_daily_plan_internal(context, existing_tasks)
    when "weekly"
      generate_weekly_plan_internal(context, existing_tasks)
    else
      generate_immediate_suggestions(context)
    end
  rescue StandardError => e
    Rails.logger.error "Auto Planner error: #{e.message}"
    fallback_plan
  end

  def suggest_actions
    context = analyze_current_context
    
    {
      immediate_suggestions: context[:suggestions],
      optimal_actions: context[:optimal_actions],
      context_summary: build_context_summary(context),
      recommended_next_steps: generate_next_steps(context)
    }
  end

  private

  def analyze_current_context
    Ai::ContextAnalyzer.analyze_context(
      user: user,
      current_time: Time.current
    )
  end

  def gather_existing_tasks
    # Собираем незавершенные задачи из записей типа 'plan'
    pending_plans = user.entries.plans
                       .where(dashboard_status: ['new', 'triaged'])
                       .recent
                       .limit(10)

    # Собираем идеи, которые можно превратить в планы
    recent_ideas = user.entries.ideas
                      .where(created_at: 3.days.ago..Time.current)
                      .where(dashboard_status: ['new', 'triaged'])
                      .recent
                      .limit(5)

    # Текущие события календаря
    today_events = user.calendar_events
                      .where(start_time: Time.current.beginning_of_day..Time.current.end_of_day)
                      .order(:start_time)

    {
      pending_plans: format_entries_for_planning(pending_plans),
      actionable_ideas: format_entries_for_planning(recent_ideas),
      calendar_events: format_calendar_events(today_events),
      available_time_slots: calculate_available_time_slots(today_events)
    }
  end

  def generate_daily_plan_internal(context, existing_tasks)
    # Определяем приоритеты на основе контекста
    priorities = determine_daily_priorities(context, existing_tasks)
    
    # Генерируем новые задачи из идей
    generated_tasks = generate_tasks_from_ideas(existing_tasks[:actionable_ideas])
    
    # Объединяем все задачи
    all_tasks = existing_tasks[:pending_plans] + generated_tasks
    
    # Оптимизируем расписание
    optimized_schedule = optimize_daily_schedule(all_tasks, existing_tasks[:calendar_events])
    
    # Создаем итоговый план
    {
      plan_type: 'daily',
      date: Date.current,
      summary: generate_daily_summary(context, optimized_schedule),
      priorities: priorities,
      scheduled_tasks: optimized_schedule[:optimized_tasks],
      recommendations: optimized_schedule[:recommendations],
      context_insights: extract_context_insights(context),
      estimated_total_time: calculate_total_time(optimized_schedule[:optimized_tasks]),
      success_probability: estimate_success_probability(optimized_schedule, context)
    }
  end

  def generate_weekly_plan_internal(context, existing_tasks)
    week_start = Date.current.beginning_of_week
    week_end = week_start.end_of_week
    
    # Анализируем недельные паттерны
    weekly_patterns = analyze_weekly_patterns
    
    # Получаем недельные события
    weekly_events = user.calendar_events
                       .where(start_time: week_start.beginning_of_day..week_end.end_of_day)
                       .order(:start_time)

    # Распределяем задачи по дням недели
    daily_distributions = distribute_tasks_across_week(
      existing_tasks[:pending_plans] + existing_tasks[:actionable_ideas],
      weekly_patterns,
      weekly_events
    )
    
    {
      plan_type: 'weekly',
      week_start: week_start,
      week_end: week_end,
      summary: generate_weekly_summary(weekly_patterns, daily_distributions),
      daily_plans: daily_distributions,
      weekly_goals: extract_weekly_goals(existing_tasks),
      focus_themes: identify_weekly_themes(existing_tasks),
      workload_balance: analyze_weekly_workload(daily_distributions)
    }
  end

  def generate_immediate_suggestions(context)
    {
      plan_type: 'immediate',
      timestamp: Time.current,
      context_summary: build_context_summary(context),
      immediate_actions: context[:optimal_actions].first(3),
      contextual_suggestions: context[:suggestions],
      quick_wins: identify_quick_wins,
      energy_optimization: suggest_energy_optimization(context)
    }
  end

  def determine_daily_priorities(context, existing_tasks)
    priorities = []
    
    # Приоритеты на основе времени
    if context[:temporal_context][:time_category] == 'morning'
      priorities << {
        type: 'time_based',
        title: 'Утренние приоритеты',
        description: 'Высокая энергия - время для сложных задач',
        weight: 0.9
      }
    end
    
    # Приоритеты на основе незавершенных задач
    overdue_tasks = existing_tasks[:pending_plans].select do |task|
      task[:created_at] < 2.days.ago
    end
    
    if overdue_tasks.any?
      priorities << {
        type: 'overdue_tasks',
        title: 'Просроченные задачи',
        description: "#{overdue_tasks.count} задач требуют внимания",
        weight: 0.8,
        tasks: overdue_tasks.first(3)
      }
    end
    
    # Приоритеты на основе продуктивности
    if context[:productivity_context][:today_activity][:productivity_score] < 30
      priorities << {
        type: 'productivity_boost',
        title: 'Повышение продуктивности',
        description: 'Сегодня низкая активность - нужен импульс',
        weight: 0.7
      }
    end
    
    priorities.sort_by { |p| -p[:weight] }
  end

  def generate_tasks_from_ideas(ideas)
    return [] if ideas.empty?
    
    ideas.map do |idea|
      # Используем AI Plan Generator для создания задач из идей
      plan_data = Ai::PlanGenerator.call(
        user: user,
        idea_content: idea[:content],
        context: "Автоматическое планирование на #{Date.current.strftime('%d.%m.%Y')}"
      )
      
      # Конвертируем план в формат задач
      plan_data[:tasks].map do |task|
        {
          id: "generated_#{SecureRandom.hex(4)}",
          title: task[:title],
          description: task[:description],
          estimated_time: task[:estimated_time].to_i,
          priority: task[:priority],
          category: task[:category],
          source: 'ai_generated',
          source_idea: idea[:id],
          suggested_time: task[:suggested_time]
        }
      end
    end.flatten.first(5) # Ограничиваем количество генерируемых задач
  end

  def optimize_daily_schedule(tasks, calendar_events)
    return { optimized_tasks: [], recommendations: [] } if tasks.empty?
    
    # Используем Schedule Optimizer
    Ai::ScheduleOptimizer.call(
      user: user,
      tasks: tasks,
      date_range: Date.current..Date.current,
      preferences: options.fetch(:scheduling_preferences, {})
    )
  end

  def generate_daily_summary(context, schedule)
    task_count = schedule[:optimized_tasks]&.count || 0
    total_time = calculate_total_time(schedule[:optimized_tasks] || [])
    
    energy_level = context[:temporal_context][:energy_level]
    productivity_score = context[:productivity_context][:today_activity][:productivity_score]
    
    summary = "План на #{Date.current.strftime('%d.%m.%Y')}: #{task_count} задач"
    summary += ", ~#{total_time} часов работы" if total_time > 0
    summary += ". Уровень энергии: #{energy_level}"
    summary += ". Текущая продуктивность: #{productivity_score}%" if productivity_score > 0
    
    if schedule[:recommendations]&.any?
      summary += ". Есть #{schedule[:recommendations].count} рекомендаций для оптимизации."
    end
    
    summary
  end

  def analyze_weekly_patterns
    return default_weekly_patterns unless user
    
    # Анализируем активность по дням недели за последний месяц
    entries_by_day = user.entries.active
                        .where(created_at: 4.weeks.ago..Time.current)
                        .group('DAYNAME(created_at)')
                        .count
    
    # Определяем самые продуктивные дни
    most_productive_days = entries_by_day.sort_by { |_, count| -count }.first(3).map(&:first)
    
    {
      productive_days: most_productive_days,
      activity_distribution: entries_by_day,
      recommended_planning_days: %w[Sunday Monday], # Стандартные дни планирования
      heavy_workload_days: %w[Tuesday Wednesday Thursday],
      recovery_days: %w[Friday Saturday]
    }
  end

  def distribute_tasks_across_week(tasks, patterns, weekly_events)
    return {} if tasks.empty?
    
    # Группируем задачи по приоритету и сложности
    high_priority = tasks.select { |t| t[:priority] == 'high' }
    medium_priority = tasks.select { |t| t[:priority] == 'medium' }
    low_priority = tasks.select { |t| t[:priority] == 'low' }
    
    daily_plans = {}
    
    # Распределяем по дням недели
    (0..6).each do |day_offset|
      date = Date.current.beginning_of_week + day_offset.days
      day_name = date.strftime('%A')
      
      # Определяем нагрузку на день
      day_workload = calculate_day_workload(date, weekly_events)
      available_capacity = estimate_daily_capacity(day_name, patterns) - day_workload
      
      daily_tasks = []
      remaining_capacity = available_capacity
      
      # Сначала высокий приоритет в продуктивные дни
      if patterns[:productive_days].include?(day_name) && high_priority.any?
        task = high_priority.shift
        daily_tasks << task if task && remaining_capacity > 0
        remaining_capacity -= (task[:estimated_time] || 30) / 60.0
      end
      
      # Потом средний приоритет
      while medium_priority.any? && remaining_capacity > 0.5
        task = medium_priority.shift
        daily_tasks << task
        remaining_capacity -= (task[:estimated_time] || 30) / 60.0
      end
      
      # В конце низкий приоритет
      if patterns[:recovery_days].include?(day_name) && low_priority.any? && remaining_capacity > 0.5
        task = low_priority.shift
        daily_tasks << task if task
      end
      
      daily_plans[date] = {
        date: date,
        day_name: day_name,
        tasks: daily_tasks,
        estimated_hours: daily_tasks.sum { |t| (t[:estimated_time] || 30) / 60.0 }.round(1),
        capacity_utilization: ((available_capacity - remaining_capacity) / available_capacity * 100).round,
        workload_level: categorize_workload(available_capacity - remaining_capacity)
      }
    end
    
    daily_plans
  end

  def format_entries_for_planning(entries)
    entries.map do |entry|
      {
        id: entry.id,
        title: entry.content.truncate(50),
        content: entry.content,
        entry_type: entry.entry_type,
        category: entry.category,
        priority: determine_priority_from_content(entry.content),
        estimated_time: estimate_time_from_content(entry.content),
        created_at: entry.created_at,
        dashboard_status: entry.dashboard_status
      }
    end
  end

  def format_calendar_events(events)
    events.map do |event|
      {
        title: event.title,
        start_time: event.start_time,
        end_time: event.end_time,
        duration_hours: ((event.end_time - event.start_time) / 1.hour).round(1),
        category: event.category
      }
    end
  end

  def calculate_available_time_slots(events)
    # Простой расчет доступного времени между событиями
    return [{ start: 9, end: 18, duration: 9 }] if events.empty?
    
    slots = []
    current_time = 9 # 9:00
    
    events.each do |event|
      event_start_hour = event.start_time.hour
      
      if current_time < event_start_hour
        slots << {
          start: current_time,
          end: event_start_hour,
          duration: event_start_hour - current_time
        }
      end
      
      current_time = [event.end_time.hour + 1, current_time].max
    end
    
    # Добавляем время до конца рабочего дня
    if current_time < 18
      slots << {
        start: current_time,
        end: 18,
        duration: 18 - current_time
      }
    end
    
    slots.select { |slot| slot[:duration] >= 1 } # Минимум час
  end

  def determine_priority_from_content(content)
    high_keywords = %w[срочно важно deadline дедлайн критично]
    medium_keywords = %w[нужно надо планирую хочу]
    
    content_lower = content.downcase
    
    if high_keywords.any? { |keyword| content_lower.include?(keyword) }
      'high'
    elsif medium_keywords.any? { |keyword| content_lower.include?(keyword) }
      'medium'
    else
      'low'
    end
  end

  def estimate_time_from_content(content)
    # Простое извлечение времени из текста
    time_patterns = [
      /(\d+)\s*час[а-я]*/i,
      /(\d+)\s*мин[а-я]*/i,
      /(\d+)\s*дн[а-я]*/i
    ]
    
    time_patterns.each do |pattern|
      match = content.match(pattern)
      if match
        number = match[1].to_i
        return case pattern.source
               when /час/ then number * 60
               when /мин/ then number
               when /дн/ then number * 8 * 60 # 8 часов в день
               end
      end
    end
    
    # Дефолтная оценка на основе длины контента
    if content.length > 200
      120 # 2 часа для длинных задач
    elsif content.length > 100
      60  # 1 час для средних задач
    else
      30  # 30 минут для коротких задач
    end
  end

  def calculate_total_time(tasks)
    return 0 if tasks.empty?
    
    total_minutes = tasks.sum { |task| (task[:estimated_time] || 30).to_i }
    (total_minutes / 60.0).round(1)
  end

  def estimate_success_probability(schedule, context)
    base_probability = 70
    
    # Корректировки на основе контекста
    energy_level = context[:temporal_context][:energy_level]
    case energy_level
    when 'high' then base_probability += 20
    when 'medium' then base_probability += 10
    when 'low' then base_probability -= 10
    when 'very_low' then base_probability -= 20
    end
    
    # Корректировки на основе рабочей нагрузки
    total_hours = calculate_total_time(schedule[:optimized_tasks] || [])
    if total_hours > 8
      base_probability -= 20 # Перегрузка снижает вероятность
    elsif total_hours < 2
      base_probability -= 10 # Слишком мало может означать отсутствие мотивации
    end
    
    # Корректировки на основе продуктивности
    productivity = context[:productivity_context][:today_activity][:productivity_score]
    if productivity > 80
      base_probability += 15
    elsif productivity < 30
      base_probability -= 15
    end
    
    [base_probability, 95].min # Максимум 95%
  end

  def extract_context_insights(context)
    insights = []
    
    # Временные инсайты
    temporal = context[:temporal_context]
    insights << {
      type: 'temporal',
      message: "Сейчас #{temporal[:time_category]} (#{temporal[:current_hour]}:00), уровень энергии: #{temporal[:energy_level]}"
    }
    
    # Поведенческие инсайты
    behavioral = context[:behavioral_context]
    if behavioral[:hours_since_last_activity] > 4
      insights << {
        type: 'behavioral',
        message: "Прошло #{behavioral[:hours_since_last_activity].round} ч. с последней активности"
      }
    end
    
    # Продуктивность
    productivity = context[:productivity_context]
    if productivity[:today_activity][:total_entries] == 0
      insights << {
        type: 'productivity',
        message: "Сегодня пока нет записей - хорошее время для планирования"
      }
    end
    
    insights
  end

  # Helper methods
  def calculate_day_workload(date, events)
    day_events = events.select { |e| e[:start_time].to_date == date }
    day_events.sum { |e| e[:duration_hours] || 1 }
  end

  def estimate_daily_capacity(day_name, patterns)
    if patterns[:productive_days].include?(day_name)
      8 # 8 часов продуктивного времени
    elsif patterns[:recovery_days].include?(day_name)
      4 # 4 часа в дни отдыха
    else
      6 # 6 часов в обычные дни
    end
  end

  def categorize_workload(hours)
    case hours
    when 0..2 then 'light'
    when 2..5 then 'moderate'
    when 5..8 then 'heavy'
    else 'overloaded'
    end
  end

  def generate_weekly_summary(patterns, distributions)
    total_tasks = distributions.values.sum { |day| day[:tasks].count }
    total_hours = distributions.values.sum { |day| day[:estimated_hours] }
    
    "Недельный план: #{total_tasks} задач, ~#{total_hours.round(1)} часов. " \
    "Самые загруженные дни: #{find_busiest_days(distributions).join(', ')}"
  end

  def extract_weekly_goals(existing_tasks)
    # Извлекаем основные цели из задач высокого приоритета
    high_priority_tasks = existing_tasks[:pending_plans].select { |t| t[:priority] == 'high' }
    
    high_priority_tasks.first(3).map do |task|
      {
        title: task[:title],
        category: task[:category],
        estimated_completion: 'this week'
      }
    end
  end

  def identify_weekly_themes(existing_tasks)
    all_tasks = existing_tasks[:pending_plans] + existing_tasks[:actionable_ideas]
    
    # Анализируем категории задач
    category_counts = all_tasks.group_by { |t| t[:category] }
                              .transform_values(&:count)
                              .sort_by { |_, count| -count }
    
    dominant_categories = category_counts.first(3).map(&:first)
    
    themes = dominant_categories.map do |category|
      case category
      when 'work' then 'Профессиональное развитие'
      when 'ideas' then 'Творчество и инновации'
      when 'health' then 'Здоровье и благополучие'
      when 'life' then 'Личная жизнь'
      else category.humanize
      end
    end
    
    themes
  end

  def analyze_weekly_workload(distributions)
    daily_hours = distributions.transform_values { |day| day[:estimated_hours] }
    
    {
      total_hours: daily_hours.values.sum.round(1),
      average_daily: (daily_hours.values.sum / 7.0).round(1),
      peak_day: daily_hours.max_by { |_, hours| hours }&.first&.strftime('%A'),
      lightest_day: daily_hours.min_by { |_, hours| hours }&.first&.strftime('%A'),
      balance_score: calculate_balance_score(daily_hours.values)
    }
  end

  def find_busiest_days(distributions)
    distributions.sort_by { |_, day| -day[:estimated_hours] }
                .first(2)
                .map { |date, _| date.strftime('%A') }
  end

  def calculate_balance_score(daily_hours)
    return 100 if daily_hours.empty?
    
    avg = daily_hours.sum / daily_hours.size.to_f
    variance = daily_hours.sum { |h| (h - avg) ** 2 } / daily_hours.size.to_f
    
    # Нормализуем к 0-100, где 100 = идеальный баланс
    balance_score = 100 - (variance * 10).round
    [balance_score, 0].max
  end

  def identify_quick_wins
    return [] unless user
    
    # Ищем простые задачи, которые можно быстро выполнить
    simple_plans = user.entries.plans
                      .where(dashboard_status: 'new')
                      .where('LENGTH(content) < ?', 100) # Короткие задачи
                      .recent
                      .limit(3)
    
    simple_plans.map do |plan|
      {
        id: plan.id,
        title: plan.content.truncate(50),
        estimated_time: 15, # Быстрые задачи
        impact: 'medium',
        effort: 'low'
      }
    end
  end

  def suggest_energy_optimization(context)
    energy_level = context[:temporal_context][:energy_level]
    hour = context[:temporal_context][:current_hour]
    
    case energy_level
    when 'high'
      {
        recommendation: 'Используйте высокую энергию для сложных задач',
        optimal_activities: ['планирование', 'анализ', 'креатив'],
        duration_suggestion: '90-120 минут фокуса'
      }
    when 'medium'
      {
        recommendation: 'Подходящее время для рутинных задач',
        optimal_activities: ['организация', 'коммуникация', 'обзор'],
        duration_suggestion: '45-60 минут работы'
      }
    when 'low'
      {
        recommendation: 'Время для легких задач или отдыха',
        optimal_activities: ['чтение', 'планирование завтра', 'рефлексия'],
        duration_suggestion: '30-45 минут активности'
      }
    else
      {
        recommendation: 'Рекомендуется отдых',
        optimal_activities: ['отдых', 'подготовка ко сну'],
        duration_suggestion: 'избегайте сложных задач'
      }
    end
  end

  def build_context_summary(context)
    temporal = context[:temporal_context]
    behavioral = context[:behavioral_context]
    
    "#{temporal[:time_category].capitalize} #{temporal[:day_of_week]}, " \
    "энергия: #{temporal[:energy_level]}, " \
    "последняя активность: #{behavioral[:hours_since_last_activity].round} ч. назад"
  end

  def generate_next_steps(context)
    suggestions = context[:suggestions]
    actions = context[:optimal_actions]
    
    next_steps = []
    
    # Преобразуем предложения в конкретные шаги
    suggestions.each do |suggestion|
      case suggestion[:type]
      when 'productivity_boost'
        next_steps << {
          action: 'choose_important_task',
          description: 'Выберите 1 важную задачу для выполнения',
          priority: 'high'
        }
      when 'daily_planning'
        next_steps << {
          action: 'create_daily_plan',
          description: 'Создайте план на сегодня',
          priority: 'high'
        }
      when 'daily_reflection'
        next_steps << {
          action: 'reflect_on_day',
          description: 'Подведите итоги дня',
          priority: 'medium'
        }
      end
    end
    
    # Добавляем оптимальные действия
    actions.first(2).each do |action|
      case action[:action]
      when 'plan_day'
        next_steps << {
          action: 'create_plan',
          description: 'Составьте подробный план на день',
          priority: 'high',
          confidence: action[:confidence]
        }
      when 'review_progress'
        next_steps << {
          action: 'check_progress',
          description: 'Проверьте прогресс по текущим задачам',
          priority: 'medium',
          confidence: action[:confidence]
        }
      end
    end
    
    next_steps.uniq { |step| step[:action] }.first(5)
  end

  def default_weekly_patterns
    {
      productive_days: %w[Monday Tuesday Wednesday],
      activity_distribution: {
        'Monday' => 10, 'Tuesday' => 12, 'Wednesday' => 11,
        'Thursday' => 8, 'Friday' => 6, 'Saturday' => 3, 'Sunday' => 2
      },
      recommended_planning_days: %w[Sunday Monday],
      heavy_workload_days: %w[Tuesday Wednesday Thursday],
      recovery_days: %w[Friday Saturday]
    }
  end

  def fallback_plan
    {
      plan_type: 'fallback',
      summary: 'Создан базовый план. Рекомендуется ручная настройка.',
      scheduled_tasks: [],
      recommendations: [
        {
          type: 'manual_planning',
          message: 'Добавьте задачи вручную через команды бота',
          priority: 'medium'
        }
      ],
      success_probability: 50
    }
  end
end
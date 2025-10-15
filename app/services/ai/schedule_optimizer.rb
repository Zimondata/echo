class Ai::ScheduleOptimizer
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :user
  attribute :tasks, default: -> { [] }
  attribute :date_range, default: -> { Date.current..7.days.from_now.to_date }
  attribute :preferences, default: -> { {} }
  
  def self.call(user:, tasks: [], date_range: nil, preferences: {})
    new(
      user: user,
      tasks: tasks,
      date_range: date_range || (Date.current..7.days.from_now.to_date),
      preferences: preferences
    ).optimize_schedule
  end

  def optimize_schedule
    return { optimized_tasks: [], recommendations: [] } if tasks.empty?

    # Анализируем паттерны пользователя
    user_patterns = analyze_user_patterns
    
    # Получаем существующие события
    existing_events = get_existing_events
    
    # Оптимизируем задачи
    optimized_tasks = optimize_task_placement(user_patterns, existing_events)
    
    # Генерируем рекомендации
    recommendations = generate_recommendations(user_patterns, optimized_tasks)
    
    {
      optimized_tasks: optimized_tasks,
      recommendations: recommendations,
      user_patterns: user_patterns,
      workload_analysis: analyze_workload(optimized_tasks)
    }
  rescue StandardError => e
    Rails.logger.error "Schedule Optimizer error: #{e.message}"
    fallback_optimization
  end

  private

  def analyze_user_patterns
    return default_patterns unless user

    entries = user.entries.active
                 .where(created_at: 4.weeks.ago..Time.current)
    
    {
      peak_hours: find_peak_hours(entries),
      productive_days: find_productive_days(entries),
      energy_patterns: analyze_energy_patterns(entries),
      preferred_categories: analyze_category_preferences(entries),
      average_session_length: calculate_average_session_length(entries)
    }
  end

  def find_peak_hours(entries)
    hourly_activity = entries.group_by { |e| e.created_at.hour }
                           .transform_values(&:count)
                           .sort_by { |_, count| -count }
                           .first(3)
                           
    hourly_activity.map do |hour, count|
      {
        hour: hour,
        activity_level: count,
        time_category: categorize_time(hour),
        energy_level: estimate_energy_level(hour)
      }
    end
  end

  def find_productive_days(entries)
    daily_productivity = entries.group_by { |e| e.created_at.strftime('%A') }
                              .transform_values { |day_entries| calculate_productivity_score(day_entries) }
                              .sort_by { |_, score| -score }
    
    daily_productivity.map do |day, score|
      {
        day: day,
        productivity_score: score,
        recommended_for_complex_tasks: score > 70
      }
    end
  end

  def analyze_energy_patterns(entries)
    morning_entries = entries.select { |e| e.created_at.hour.between?(6, 11) }
    afternoon_entries = entries.select { |e| e.created_at.hour.between?(12, 17) }
    evening_entries = entries.select { |e| e.created_at.hour.between?(18, 22) }
    
    {
      morning: {
        activity_level: morning_entries.count,
        avg_productivity: calculate_productivity_score(morning_entries),
        best_for: determine_best_task_types(morning_entries)
      },
      afternoon: {
        activity_level: afternoon_entries.count,
        avg_productivity: calculate_productivity_score(afternoon_entries),
        best_for: determine_best_task_types(afternoon_entries)
      },
      evening: {
        activity_level: evening_entries.count,
        avg_productivity: calculate_productivity_score(evening_entries),
        best_for: determine_best_task_types(evening_entries)
      }
    }
  end

  def analyze_category_preferences(entries)
    entries.group_by(&:category)
          .transform_values(&:count)
          .sort_by { |_, count| -count }
          .to_h
  end

  def calculate_average_session_length(entries)
    return 45 if entries.empty?
    
    # Группируем записи по дням и смотрим среднюю "сессию"
    daily_counts = entries.group_by { |e| e.created_at.to_date }
                         .transform_values(&:count)
    
    avg_entries_per_day = daily_counts.values.sum / daily_counts.size.to_f
    # Предполагаем, что каждая запись = ~15 минут активности
    (avg_entries_per_day * 15).round
  end

  def get_existing_events
    return [] unless user

    user.calendar_events
        .where(start_time: date_range.first.beginning_of_day..date_range.last.end_of_day)
        .order(:start_time)
        .map do |event|
      {
        title: event.title,
        start_time: event.start_time,
        end_time: event.end_time,
        duration: ((event.end_time - event.start_time) / 1.hour).round(1),
        category: event.category || 'other'
      }
    end
  end

  def optimize_task_placement(patterns, existing_events)
    tasks.map do |task|
      optimal_slot = find_optimal_time_slot(task, patterns, existing_events)
      
      task.merge(
        suggested_start_time: optimal_slot[:start_time],
        suggested_end_time: optimal_slot[:end_time],
        confidence_score: optimal_slot[:confidence],
        reasoning: optimal_slot[:reasoning],
        alternative_slots: find_alternative_slots(task, patterns, existing_events)
      )
    end
  end

  def find_optimal_time_slot(task, patterns, existing_events)
    task_duration = (task[:estimated_time] || 30).to_i
    task_priority = task[:priority] || 'medium'
    task_category = task[:category] || 'ideas'
    
    # Найдем лучшие временные слоты на основе паттернов
    best_hours = get_best_hours_for_task(task, patterns)
    best_days = get_best_days_for_task(task, patterns)
    
    # Ищем свободное время в оптимальные периоды
    date_range.each do |date|
      next unless best_days.any? { |d| d[:day] == date.strftime('%A') }
      
      best_hours.each do |hour_info|
        start_time = date.beginning_of_day + hour_info[:hour].hours
        end_time = start_time + task_duration.minutes
        
        if time_slot_available?(start_time, end_time, existing_events)
          return {
            start_time: start_time,
            end_time: end_time,
            confidence: calculate_confidence_score(task, hour_info, date),
            reasoning: build_reasoning(task, hour_info, date, patterns)
          }
        end
      end
    end
    
    # Если оптимальное время не найдено, ищем любое подходящее
    fallback_time_slot(task, existing_events)
  end

  def get_best_hours_for_task(task, patterns)
    task_type = determine_task_complexity(task)
    
    case task_type
    when 'complex'
      patterns[:peak_hours].select { |h| h[:energy_level] == 'high' }
    when 'creative'
      patterns[:peak_hours].select { |h| %w[morning evening].include?(h[:time_category]) }
    when 'routine'
      patterns[:peak_hours] # Любое активное время
    else
      patterns[:peak_hours].first(2) # Топ 2 часа активности
    end
  end

  def get_best_days_for_task(task, patterns)
    task_priority = task[:priority] || 'medium'
    
    if task_priority == 'high'
      patterns[:productive_days].select { |d| d[:recommended_for_complex_tasks] }
    else
      patterns[:productive_days].first(5) # Топ 5 дней
    end
  end

  def time_slot_available?(start_time, end_time, existing_events)
    existing_events.none? do |event|
      # Проверяем пересечение временных интервалов
      event_start = event[:start_time]
      event_end = event[:end_time]
      
      (start_time < event_end) && (end_time > event_start)
    end
  end

  def calculate_confidence_score(task, hour_info, date)
    base_score = 70
    
    # Бонус за оптимальное время
    base_score += 20 if hour_info[:energy_level] == 'high'
    base_score += 10 if hour_info[:energy_level] == 'medium'
    
    # Бонус за продуктивный день
    base_score += 10 if date.strftime('%A') == 'Monday' # Предполагаем понедельник продуктивный
    
    [base_score, 95].min
  end

  def build_reasoning(task, hour_info, date, patterns)
    reasons = []
    
    reasons << "#{hour_info[:hour]}:00 - одно из ваших самых активных времен"
    
    if hour_info[:energy_level] == 'high'
      reasons << "высокий уровень энергии в это время"
    end
    
    if date.strftime('%A').in?(%w[Monday Tuesday Wednesday])
      reasons << "#{date.strftime('%A')} обычно продуктивный день"
    end
    
    reasons.join('; ')
  end

  def find_alternative_slots(task, patterns, existing_events)
    alternatives = []
    task_duration = (task[:estimated_time] || 30).to_i
    
    # Ищем 2-3 альтернативных слота
    date_range.each do |date|
      (9..18).each do |hour|
        start_time = date.beginning_of_day + hour.hours
        end_time = start_time + task_duration.minutes
        
        if time_slot_available?(start_time, end_time, existing_events)
          alternatives << {
            start_time: start_time,
            end_time: end_time,
            confidence: calculate_confidence_score(task, { hour: hour, energy_level: 'medium' }, date)
          }
          
          break if alternatives.size >= 3
        end
      end
      
      break if alternatives.size >= 3
    end
    
    alternatives
  end

  def generate_recommendations(patterns, optimized_tasks)
    recommendations = []
    
    # Анализ рабочей нагрузки
    daily_workload = analyze_daily_workload(optimized_tasks)
    overloaded_days = daily_workload.select { |_, load| load > 6 } # > 6 часов в день
    
    if overloaded_days.any?
      recommendations << {
        type: 'workload_warning',
        message: "Перегруженные дни: #{overloaded_days.keys.join(', ')}. Рассмотрите перераспределение задач.",
        priority: 'high'
      }
    end
    
    # Рекомендации по оптимизации
    if patterns[:energy_patterns][:morning][:avg_productivity] > 80
      recommendations << {
        type: 'energy_optimization',
        message: "Ваша продуктивность утром высокая. Планируйте сложные задачи на 8-11:00.",
        priority: 'medium'
      }
    end
    
    # Рекомендации по балансу
    category_balance = analyze_category_balance(optimized_tasks)
    if category_balance[:work] > 0.7
      recommendations << {
        type: 'balance_suggestion',
        message: "Много рабочих задач. Добавьте время для отдыха и личных дел.",
        priority: 'medium'
      }
    end
    
    recommendations
  end

  def analyze_workload(optimized_tasks)
    {
      total_hours: calculate_total_hours(optimized_tasks),
      daily_breakdown: analyze_daily_workload(optimized_tasks),
      category_distribution: analyze_category_distribution(optimized_tasks)
    }
  end

  # Helper methods
  def categorize_time(hour)
    case hour
    when 6..11 then 'morning'
    when 12..17 then 'afternoon'  
    when 18..22 then 'evening'
    else 'night'
    end
  end

  def estimate_energy_level(hour)
    case hour
    when 8..11, 14..16 then 'high'
    when 6..7, 12..13, 17..19 then 'medium'
    else 'low'
    end
  end

  def calculate_productivity_score(entries)
    return 50 if entries.empty?
    
    plan_ratio = entries.count(&:plan?) / entries.size.to_f
    idea_ratio = entries.count(&:idea?) / entries.size.to_f
    
    ((plan_ratio * 60) + (idea_ratio * 30) + 40).round
  end

  def determine_best_task_types(entries)
    types = entries.map(&:entry_type).tally
    dominant_type = types.max_by { |_, count| count }&.first
    
    case dominant_type
    when 'plan' then ['planning', 'execution']
    when 'idea' then ['creative', 'brainstorming']
    when 'diary' then ['reflection', 'routine']
    else ['general']
    end
  end

  def determine_task_complexity(task)
    duration = (task[:estimated_time] || 30).to_i
    priority = task[:priority] || 'medium'
    
    if duration > 90 || priority == 'high'
      'complex'
    elsif task[:category] == 'ideas'
      'creative'
    elsif duration < 30
      'routine'
    else
      'standard'
    end
  end

  def fallback_time_slot(task, existing_events)
    # Простой алгоритм: первое свободное время завтра в 10:00
    tomorrow = Date.current + 1
    start_time = tomorrow.beginning_of_day + 10.hours
    duration = (task[:estimated_time] || 30).to_i
    
    {
      start_time: start_time,
      end_time: start_time + duration.minutes,
      confidence: 50,
      reasoning: "Запланировано на завтра утром (свободное время)"
    }
  end

  def analyze_daily_workload(tasks)
    tasks.group_by { |t| t[:suggested_start_time]&.to_date }
         .transform_values { |day_tasks| 
           day_tasks.sum { |t| (t[:estimated_time] || 30).to_i } / 60.0 
         }
  end

  def analyze_category_balance(tasks)
    total = tasks.size
    return {} if total == 0
    
    tasks.group_by { |t| t[:category] }
         .transform_values { |cat_tasks| cat_tasks.size / total.to_f }
  end

  def analyze_category_distribution(tasks)
    tasks.group_by { |t| t[:category] }
         .transform_values(&:size)
  end

  def calculate_total_hours(tasks)
    tasks.sum { |t| (t[:estimated_time] || 30).to_i } / 60.0
  end

  def default_patterns
    {
      peak_hours: [
        { hour: 9, activity_level: 10, time_category: 'morning', energy_level: 'high' },
        { hour: 14, activity_level: 8, time_category: 'afternoon', energy_level: 'high' },
        { hour: 19, activity_level: 6, time_category: 'evening', energy_level: 'medium' }
      ],
      productive_days: [
        { day: 'Monday', productivity_score: 85, recommended_for_complex_tasks: true },
        { day: 'Tuesday', productivity_score: 80, recommended_for_complex_tasks: true },
        { day: 'Wednesday', productivity_score: 75, recommended_for_complex_tasks: true }
      ],
      energy_patterns: {
        morning: { activity_level: 8, avg_productivity: 80, best_for: ['planning', 'complex'] },
        afternoon: { activity_level: 6, avg_productivity: 70, best_for: ['execution'] },
        evening: { activity_level: 4, avg_productivity: 60, best_for: ['reflection', 'routine'] }
      },
      preferred_categories: { 'work' => 15, 'ideas' => 8, 'life' => 5 },
      average_session_length: 45
    }
  end

  def fallback_optimization
    {
      optimized_tasks: tasks.map do |task|
        task.merge(
          suggested_start_time: Date.current.beginning_of_day + 10.hours,
          suggested_end_time: Date.current.beginning_of_day + 10.hours + 30.minutes,
          confidence_score: 50,
          reasoning: "Базовое планирование - потребуется ручная настройка"
        )
      end,
      recommendations: [
        {
          type: 'system_error',
          message: "Произошла ошибка при оптимизации. Используется базовое планирование.",
          priority: 'low'
        }
      ]
    }
  end
end
class Ai::ContextAnalyzer
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :user
  attribute :current_time, default: -> { Time.current }
  attribute :location_data, default: -> { {} }
  attribute :recent_activity, default: -> { [] }
  
  def self.analyze_context(user:, current_time: Time.current, location_data: {}, recent_activity: [])
    new(
      user: user,
      current_time: current_time,
      location_data: location_data,
      recent_activity: recent_activity
    ).analyze
  end

  def analyze
    {
      temporal_context: analyze_temporal_context,
      behavioral_context: analyze_behavioral_context,
      productivity_context: analyze_productivity_context,
      suggestions: generate_contextual_suggestions,
      optimal_actions: determine_optimal_actions
    }
  rescue StandardError => e
    Rails.logger.error "Context Analyzer error: #{e.message}"
    fallback_context
  end

  private

  def analyze_temporal_context
    hour = current_time.hour
    day_of_week = current_time.strftime('%A')
    
    {
      current_hour: hour,
      day_of_week: day_of_week,
      time_category: categorize_time_period(hour),
      is_weekend: weekend?,
      is_business_hours: business_hours?,
      energy_level: estimate_energy_level(hour),
      typical_activity: get_typical_activity_for_time
    }
  end

  def analyze_behavioral_context
    return default_behavioral_context unless user

    recent_entries = user.entries.active
                        .where(created_at: 24.hours.ago..current_time)
                        .order(:created_at)

    last_activity = recent_entries.last
    
    {
      last_activity_time: last_activity&.created_at,
      last_activity_type: last_activity&.entry_type,
      hours_since_last_activity: calculate_hours_since_last_activity(last_activity),
      recent_patterns: analyze_recent_patterns(recent_entries),
      current_streak: analyze_current_streak,
      engagement_level: calculate_engagement_level(recent_entries)
    }
  end

  def analyze_productivity_context
    return default_productivity_context unless user

    today_entries = user.entries.active
                       .where(created_at: current_time.beginning_of_day..current_time)
    
    week_entries = user.entries.active
                      .where(created_at: current_time.beginning_of_week..current_time)

    {
      today_activity: {
        total_entries: today_entries.count,
        by_type: today_entries.group(:entry_type).count,
        productivity_score: calculate_daily_productivity(today_entries)
      },
      week_comparison: {
        current_week_total: week_entries.count,
        avg_week_total: calculate_average_weekly_entries,
        trend: determine_weekly_trend(week_entries)
      },
      focus_areas: identify_current_focus_areas(week_entries),
      completion_status: analyze_completion_status
    }
  end

  def generate_contextual_suggestions
    suggestions = []
    context = {
      temporal: analyze_temporal_context,
      behavioral: analyze_behavioral_context,
      productivity: analyze_productivity_context
    }
    
    # Временные предложения
    if context[:temporal][:energy_level] == 'high' && context[:productivity][:today_activity][:total_entries] < 3
      suggestions << {
        type: 'productivity_boost',
        message: "Сейчас у вас высокий уровень энергии! Самое время заняться важной задачей.",
        priority: 'high',
        action: 'suggest_important_task'
      }
    end
    
    # Предложения на основе паттернов
    if context[:behavioral][:hours_since_last_activity] > 4
      suggestions << {
        type: 'engagement_reminder',
        message: "Прошло #{context[:behavioral][:hours_since_last_activity].round} часов с последней записи. Как дела?",
        priority: 'medium',
        action: 'encourage_check_in'
      }
    end
    
    # Планирование на основе времени
    if context[:temporal][:time_category] == 'morning' && context[:productivity][:today_activity][:total_entries] == 0
      suggestions << {
        type: 'daily_planning',
        message: "Доброе утро! Давайте спланируем день. Что у вас в приоритете?",
        priority: 'high',
        action: 'start_daily_planning'
      }
    end
    
    # Вечерние рефлексии
    if context[:temporal][:time_category] == 'evening' && !daily_reflection_done?
      suggestions << {
        type: 'daily_reflection',
        message: "Время подвести итоги дня. Что удалось сегодня?",
        priority: 'medium',
        action: 'encourage_reflection'
      }
    end
    
    # Выходные предложения
    if context[:temporal][:is_weekend] && context[:productivity][:focus_areas].include?('work')
      suggestions << {
        type: 'work_life_balance',
        message: "Выходной день - время для отдыха и личных дел!",
        priority: 'low',
        action: 'suggest_personal_time'
      }
    end
    
    suggestions
  end

  def determine_optimal_actions
    context = analyze_temporal_context
    behavioral = analyze_behavioral_context
    
    actions = []
    
    case context[:time_category]
    when 'morning'
      if behavioral[:engagement_level] == 'high'
        actions << { action: 'plan_day', confidence: 0.9 }
        actions << { action: 'tackle_complex_task', confidence: 0.8 }
      else
        actions << { action: 'gentle_check_in', confidence: 0.7 }
      end
      
    when 'afternoon'
      actions << { action: 'review_progress', confidence: 0.8 }
      actions << { action: 'handle_routine_tasks', confidence: 0.7 }
      
    when 'evening'
      actions << { action: 'reflect_on_day', confidence: 0.9 }
      actions << { action: 'plan_tomorrow', confidence: 0.7 }
      
    when 'night'
      actions << { action: 'encourage_rest', confidence: 0.8 }
    end
    
    # Добавляем действия на основе недавней активности
    if behavioral[:hours_since_last_activity] > 6
      actions << { action: 'reconnect', confidence: 0.9 }
    elsif behavioral[:hours_since_last_activity] < 1
      actions << { action: 'continue_momentum', confidence: 0.8 }
    end
    
    actions.sort_by { |a| -a[:confidence] }
  end

  # Helper methods
  def categorize_time_period(hour)
    case hour
    when 5..11 then 'morning'
    when 12..17 then 'afternoon'
    when 18..22 then 'evening'
    else 'night'
    end
  end

  def weekend?
    current_time.saturday? || current_time.sunday?
  end

  def business_hours?
    hour = current_time.hour
    weekday = !weekend?
    weekday && hour.between?(9, 18)
  end

  def estimate_energy_level(hour)
    case hour
    when 7..10, 14..16 then 'high'
    when 11..13, 17..19 then 'medium'
    when 20..22, 6 then 'low'
    else 'very_low'
    end
  end

  def get_typical_activity_for_time
    return nil unless user

    # Анализируем что обычно делает пользователь в это время
    similar_hour_entries = user.entries.active
                              .where('EXTRACT(hour FROM created_at) = ?', current_time.hour)
                              .where(created_at: 4.weeks.ago..current_time)
                              .limit(10)

    return 'no_pattern' if similar_hour_entries.empty?

    most_common_type = similar_hour_entries.group(:entry_type)
                                          .count
                                          .max_by { |_, count| count }
                                          &.first

    most_common_category = similar_hour_entries.group(:category)
                                              .count
                                              .max_by { |_, count| count }
                                              &.first

    {
      typical_entry_type: most_common_type,
      typical_category: most_common_category,
      frequency: similar_hour_entries.count
    }
  end

  def calculate_hours_since_last_activity(last_entry)
    return 24 unless last_entry
    
    ((current_time - last_entry.created_at) / 1.hour).round(1)
  end

  def analyze_recent_patterns(entries)
    return {} if entries.empty?
    
    {
      dominant_type: entries.group(:entry_type).count.max_by { |_, count| count }&.first,
      dominant_category: entries.group(:category).count.max_by { |_, count| count }&.first,
      activity_trend: determine_activity_trend(entries),
      mood_indicators: extract_mood_indicators(entries)
    }
  end

  def analyze_current_streak
    return { streak_type: 'none', duration: 0 } unless user

    # Анализируем последовательные дни активности
    recent_days = user.entries.active
                     .where(created_at: 7.days.ago..current_time)
                     .group('DATE(created_at)')
                     .count

    consecutive_days = count_consecutive_active_days(recent_days)
    
    if consecutive_days >= 3
      { streak_type: 'active', duration: consecutive_days }
    elsif consecutive_days == 0
      { streak_type: 'break', duration: days_since_last_activity }
    else
      { streak_type: 'building', duration: consecutive_days }
    end
  end

  def calculate_engagement_level(entries)
    return 'low' if entries.empty?
    
    entry_count = entries.count
    hours_span = 24
    avg_per_hour = entry_count / hours_span.to_f
    
    case avg_per_hour
    when 0.5..Float::INFINITY then 'high'
    when 0.2..0.5 then 'medium'
    when 0.1..0.2 then 'low'
    else 'very_low'
    end
  end

  def calculate_daily_productivity(entries)
    return 0 if entries.empty?
    
    plan_ratio = entries.count(&:plan?) / entries.size.to_f
    completion_bonus = calculate_completion_bonus(entries)
    time_bonus = calculate_time_distribution_bonus(entries)
    
    base_score = (plan_ratio * 40) + 30
    total_score = base_score + completion_bonus + time_bonus
    
    [total_score, 100].min.round
  end

  def calculate_average_weekly_entries
    return 0 unless user
    
    user.entries.active
        .where(created_at: 8.weeks.ago..current_time)
        .group('YEAR(created_at), WEEK(created_at)')
        .count
        .values
        .sum / 8.0
  end

  def determine_weekly_trend(week_entries)
    avg_weekly = calculate_average_weekly_entries
    current_week_count = week_entries.count
    
    if current_week_count > avg_weekly * 1.2
      'increasing'
    elsif current_week_count < avg_weekly * 0.8
      'decreasing'
    else
      'stable'
    end
  end

  def identify_current_focus_areas(entries)
    return [] if entries.empty?
    
    category_counts = entries.group(:category).count
    total = entries.count
    
    category_counts.filter_map do |category, count|
      percentage = count / total.to_f
      category if percentage > 0.3 # Категории составляющие >30% активности
    end
  end

  def analyze_completion_status
    return {} unless user
    
    today_plans = user.entries.plans
                     .where(created_at: current_time.beginning_of_day..current_time)
    
    return {} if today_plans.empty?
    
    completed = today_plans.count { |p| p.dashboard_status == 'processed' }
    
    {
      total_plans: today_plans.count,
      completed: completed,
      completion_rate: (completed / today_plans.count.to_f * 100).round,
      needs_attention: today_plans.needs_attention.count
    }
  end

  def daily_reflection_done?
    return false unless user
    
    user.entries.diaries
        .where(created_at: current_time.beginning_of_day..current_time)
        .exists?
  end

  def determine_activity_trend(entries)
    timestamps = entries.order(:created_at).pluck(:created_at)
    return 'stable' if timestamps.size < 3
    
    # Простой анализ: сравниваем интервалы между записями
    intervals = timestamps.each_cons(2).map { |a, b| b - a }
    avg_interval = intervals.sum / intervals.size
    recent_interval = intervals.last
    
    if recent_interval < avg_interval * 0.7
      'accelerating'
    elsif recent_interval > avg_interval * 1.5
      'slowing'
    else
      'stable'
    end
  end

  def extract_mood_indicators(entries)
    positive_words = %w[отлично хорошо успешно продуктивно радость счастье]
    negative_words = %w[плохо устал сложно проблема стресс грусть]
    
    all_content = entries.pluck(:content).join(' ').downcase
    
    positive_count = positive_words.count { |word| all_content.include?(word) }
    negative_count = negative_words.count { |word| all_content.include?(word) }
    
    if positive_count > negative_count
      'positive'
    elsif negative_count > positive_count
      'negative'
    else
      'neutral'
    end
  end

  def count_consecutive_active_days(daily_counts)
    sorted_dates = daily_counts.keys.sort.reverse
    consecutive = 0
    
    sorted_dates.each do |date|
      if daily_counts[date] > 0
        consecutive += 1
      else
        break
      end
    end
    
    consecutive
  end

  def days_since_last_activity
    return 0 unless user
    
    last_entry = user.entries.active.order(:created_at).last
    return 30 unless last_entry # Если записей нет, считаем что давно
    
    ((current_time - last_entry.created_at) / 1.day).round
  end

  def calculate_completion_bonus(entries)
    plan_entries = entries.select(&:plan?)
    return 0 if plan_entries.empty?
    
    completed_count = plan_entries.count { |e| e.dashboard_status == 'processed' }
    completion_rate = completed_count / plan_entries.size.to_f
    
    completion_rate * 20 # До 20 бонусных баллов за выполнение
  end

  def calculate_time_distribution_bonus(entries)
    return 0 if entries.empty?
    
    hours = entries.map { |e| e.created_at.hour }.uniq
    
    # Бонус за распределение активности в течение дня
    if hours.size >= 3
      10
    elsif hours.size >= 2
      5
    else
      0
    end
  end

  # Default fallbacks
  def default_behavioral_context
    {
      last_activity_time: nil,
      last_activity_type: nil,
      hours_since_last_activity: 24,
      recent_patterns: {},
      current_streak: { streak_type: 'none', duration: 0 },
      engagement_level: 'unknown'
    }
  end

  def default_productivity_context
    {
      today_activity: { total_entries: 0, by_type: {}, productivity_score: 0 },
      week_comparison: { current_week_total: 0, avg_week_total: 0, trend: 'unknown' },
      focus_areas: [],
      completion_status: {}
    }
  end

  def fallback_context
    {
      temporal_context: analyze_temporal_context,
      behavioral_context: default_behavioral_context,
      productivity_context: default_productivity_context,
      suggestions: [],
      optimal_actions: [{ action: 'basic_check_in', confidence: 0.5 }]
    }
  end
end
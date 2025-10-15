class GenerateInsightJob < ApplicationJob
  queue_as :default

  def perform(user_id, insight_type, options = {})
    @user = User.find(user_id)
    @insight_type = insight_type
    @options = options

    case insight_type
    when 'daily_summary'
      generate_daily_summary
    when 'weekly_digest'
      generate_weekly_digest
    when 'trend_analysis'
      generate_trend_analysis
    when 'productivity_insight'
      generate_productivity_insight
    when 'mood_tracker'
      generate_mood_tracker
    else
      Rails.logger.error "Unknown insight type: #{insight_type}"
    end
  end

  private

  def generate_daily_summary
    date = @options[:date] || Date.current
    entries = @user.entries.active
                .where('DATE(created_at) = ?', date)

    return if entries.empty?

    # Собираем детальную статистику
    stats = Analytics::UserStatsCollector.daily_stats(@user, date)
    
    # Подготавливаем данные для AI анализа
    content_for_analysis = entries.map { |e| 
      "#{e.entry_type.capitalize}: #{e.content.truncate(200)}" 
    }.join("\n\n")

    # Генерируем инсайт с помощью AI
    ai_summary = Ai::InsightGenerator.call(
      content: content_for_analysis,
      insight_type: 'daily_summary',
      context: stats.merge(date: date)
    )

    create_insight(
      title: "Daily Summary for #{date.strftime('%B %d, %Y')}",
      content: ai_summary[:summary],
      data: stats.merge({
        highlights: ai_summary[:highlights],
        mood: ai_summary[:mood],
        key_themes: ai_summary[:themes]
      }),
      expires_at: 7.days.from_now
    )
  end

  def generate_weekly_digest
    week_start = @options[:week_start] || 1.week.ago.beginning_of_week
    entries = @user.entries.active
                .where(created_at: week_start..week_start.end_of_week)

    return if entries.empty?

    # Собираем детальную недельную статистику
    stats = Analytics::UserStatsCollector.weekly_stats(@user, week_start.to_date)

    # Собираем контент для AI
    weekly_content = prepare_weekly_content(entries)
    
    ai_digest = Ai::InsightGenerator.call(
      content: weekly_content,
      insight_type: 'weekly_digest',
      context: stats.merge({
        week_start: week_start,
        week_end: week_start.end_of_week
      })
    )

    create_insight(
      title: "Weekly Digest: #{week_start.strftime('%b %d')} - #{week_start.end_of_week.strftime('%b %d, %Y')}",
      content: ai_digest[:digest],
      data: stats.merge({
        period: { start: week_start, end: week_start.end_of_week },
        achievements: ai_digest[:achievements],
        insights: ai_digest[:insights],
        goals_for_next_week: ai_digest[:goals]
      }),
      expires_at: 2.weeks.from_now
    )
  end

  def generate_trend_analysis
    period = @options[:period] || '1_month'
    entries = case period
              when '1_month'
                @user.entries.active.where('created_at >= ?', 1.month.ago)
              when '3_months'  
                @user.entries.active.where('created_at >= ?', 3.months.ago)
              else
                @user.entries.active.where('created_at >= ?', 1.month.ago)
              end

    return if entries.count < 10

    trends = analyze_trends(entries)
    
    ai_analysis = Ai::InsightGenerator.call(
      content: format_trends_for_ai(trends),
      insight_type: 'trend_analysis',
      context: {
        period: period,
        entries_count: entries.count
      }
    )

    create_insight(
      title: "Trend Analysis: #{period.humanize}",
      content: ai_analysis[:analysis],
      data: {
        period: period,
        trends: trends,
        patterns: ai_analysis[:patterns],
        recommendations: ai_analysis[:recommendations],
        growth_areas: ai_analysis[:growth_areas]
      },
      expires_at: 1.month.from_now
    )
  end

  def generate_productivity_insight
    entries = @user.entries.active
                .where('created_at >= ?', 2.weeks.ago)

    productivity_metrics = calculate_productivity_metrics(entries)
    
    ai_insight = Ai::InsightGenerator.call(
      content: format_productivity_data(productivity_metrics),
      insight_type: 'productivity_insight',
      context: {
        period: '2_weeks',
        metrics: productivity_metrics
      }
    )

    create_insight(
      title: "Productivity Insights: Last 2 Weeks",
      content: ai_insight[:insight],
      data: {
        metrics: productivity_metrics,
        peak_hours: find_peak_productivity_hours(entries),
        best_days: find_most_productive_days(entries),
        suggestions: ai_insight[:suggestions],
        focus_areas: ai_insight[:focus_areas]
      },
      expires_at: 1.week.from_now
    )
  end

  def create_insight(title:, content:, data:, expires_at: nil)
    @user.insights.create!(
      insight_type: @insight_type,
      title: title,
      content: content,
      data: data,
      generated_at: Time.current,
      expires_at: expires_at
    )
  end

  def prepare_weekly_content(entries)
    entries.group_by(&:entry_type).map do |type, type_entries|
      "#{type.capitalize} entries (#{type_entries.count}):\n" +
      type_entries.first(5).map { |e| "- #{e.content.truncate(100)}" }.join("\n")
    end.join("\n\n")
  end

  def analyze_trends(entries)
    {
      volume_trend: analyze_volume_trend(entries),
      category_trends: analyze_category_trends(entries),
      mood_trend: analyze_mood_trend(entries),
      productivity_trend: analyze_productivity_trend(entries)
    }
  end

  def analyze_volume_trend(entries)
    # Группируем записи по неделям за последние 4 недели
    weekly_counts = {}
    4.times do |i|
      week_start = (4 - i).weeks.ago.beginning_of_week
      week_end = week_start.end_of_week
      week_entries = entries.select { |e| e.created_at >= week_start && e.created_at <= week_end }
      weekly_counts[week_start.strftime('%Y-W%U')] = week_entries.count
    end
    
    counts = weekly_counts.values
    return 'stable' if counts.empty?
    
    if counts.last > counts.first * 1.2
      'increasing'
    elsif counts.last < counts.first * 0.8
      'decreasing'
    else
      'stable'
    end
  end

  def analyze_category_trends(entries)
    entries.group_by(&:category).transform_values do |cat_entries|
      # Анализ тренда для каждой категории
      weekly_counts = {}
      4.times do |i|
        week_start = (4 - i).weeks.ago.beginning_of_week
        week_end = week_start.end_of_week
        week_entries = cat_entries.select { |e| e.created_at >= week_start && e.created_at <= week_end }
        weekly_counts[week_start.strftime('%Y-W%U')] = week_entries.count
      end
      
      {
        total: cat_entries.count,
        trend: calculate_trend_direction(weekly_counts.values)
      }
    end
  end

  def calculate_trend_direction(values)
    return 'stable' if values.size < 2
    
    trend = values.each_cons(2).map { |a, b| b <=> a }.sum
    case trend
    when -Float::INFINITY..-1 then 'decreasing'
    when 1..Float::INFINITY then 'increasing'
    else 'stable'
    end
  end

  def calculate_productivity_score(entries)
    # Простая формула продуктивности
    plans_count = entries.count(&:plan?)
    ideas_count = entries.count(&:idea?)
    total = entries.count
    
    return 0 if total == 0
    
    ((plans_count * 2 + ideas_count) / total.to_f * 100).round(1)
  end

  def calculate_productivity_metrics(entries)
    {
      total_entries: entries.count,
      plans_ratio: entries.count(&:plan?) / entries.count.to_f,
      ideas_ratio: entries.count(&:idea?) / entries.count.to_f,
      completion_rate: calculate_completion_rate(entries),
      focus_score: calculate_focus_score(entries)
    }
  end

  def calculate_completion_rate(entries)
    plan_entries = entries.select(&:plan?)
    return 0 if plan_entries.empty?
    
    completed = plan_entries.count { |e| e.dashboard_status == 'processed' }
    (completed / plan_entries.count.to_f * 100).round(1)
  end

  def calculate_focus_score(entries)
    # Оценка фокуса на основе разнообразия категорий
    categories_count = entries.map(&:category).uniq.count
    return 100 if categories_count <= 2
    
    [100 - (categories_count - 2) * 10, 0].max
  end

  def find_peak_productivity_hours(entries)
    entries.group_by { |e| e.created_at.hour }
          .transform_values(&:count)
          .sort_by { |_, count| -count }
          .first(3)
          .map { |hour, count| { hour: hour, count: count } }
  end

  def find_most_productive_days(entries)
    entries.group_by { |e| e.created_at.strftime('%A') }
          .transform_values(&:count)
          .sort_by { |_, count| -count }
          .first(3)
          .map { |day, count| { day: day, count: count } }
  end

  # Заглушки для AI методов - в реальности нужно интегрировать с OpenAI
  def format_trends_for_ai(trends)
    "Trends analysis data: #{trends.to_json}"
  end

  def format_productivity_data(metrics)
    "Productivity metrics: #{metrics.to_json}"
  end

  def analyze_mood_trend(entries)
    'stable' # Заглушка
  end

  def analyze_productivity_trend(entries)
    'stable' # Заглушка
  end
end
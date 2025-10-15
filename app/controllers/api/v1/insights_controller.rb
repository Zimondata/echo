class Api::V1::InsightsController < Api::BaseController
  def index
    insights = current_user.insights.active

    insights = insights.by_type(params[:type]) if params[:type].present?
    insights = insights.recent

    paginated = paginate(insights, per_page: 10)
    paginated[:data] = paginated[:data].map { |insight| serialize_insight(insight) }

    success_response(paginated)
  end

  def show
    insight = current_user.insights.find(params[:id])
    success_response(serialize_insight_full(insight))
  end

  def generate
    insight_type = params[:insight_type] || 'daily_summary'
    
    case insight_type
    when 'daily_summary'
      generate_daily_summary
    when 'weekly_digest'
      generate_weekly_digest
    when 'trend_analysis'
      generate_trend_analysis
    when 'productivity_insight'
      generate_productivity_insight
    else
      error_response("Unknown insight type: #{insight_type}")
    end
  end

  def analytics
    data = {
      mood_trends: mood_trends_data,
      productivity_trends: productivity_trends_data,
      category_distribution: category_distribution_data,
      weekly_activity: weekly_activity_data,
      entry_types_over_time: entry_types_over_time_data
    }

    success_response(data)
  end

  private

  def generate_daily_summary
    today_entries = current_user.entries.active
                      .where('created_at >= ?', Date.current.beginning_of_day)

    return error_response("No entries found for today") if today_entries.empty?

    # Генерируем инсайт с помощью AI
    GenerateInsightJob.perform_later(current_user.id, 'daily_summary', {
      date: Date.current,
      entries_count: today_entries.count
    })

    success_response({ message: "Daily summary generation started" })
  end

  def generate_weekly_digest
    week_entries = current_user.entries.active
                     .where('created_at >= ?', 1.week.ago)

    return error_response("No entries found for this week") if week_entries.empty?

    GenerateInsightJob.perform_later(current_user.id, 'weekly_digest', {
      week_start: 1.week.ago.beginning_of_week,
      entries_count: week_entries.count
    })

    success_response({ message: "Weekly digest generation started" })
  end

  def generate_trend_analysis
    entries = current_user.entries.active
                .where('created_at >= ?', 1.month.ago)

    return error_response("Not enough data for trend analysis") if entries.count < 10

    GenerateInsightJob.perform_later(current_user.id, 'trend_analysis', {
      period: '1_month',
      entries_count: entries.count
    })

    success_response({ message: "Trend analysis generation started" })
  end

  def generate_productivity_insight
    entries = current_user.entries.active
                .where('created_at >= ?', 2.weeks.ago)

    GenerateInsightJob.perform_later(current_user.id, 'productivity_insight', {
      period: '2_weeks',
      entries_count: entries.count
    })

    success_response({ message: "Productivity insight generation started" })
  end

  def mood_trends_data
    # Анализ настроения за последние 30 дней
    entries = current_user.entries.active
                .where('created_at >= ?', 30.days.ago)
                .where.not("insights -> 'mood' IS NULL")

    # Группируем записи по дням за последние 30 дней
    mood_data = (30.days.ago.to_date..Date.current).map do |date|
      day_entries = entries.select { |e| e.created_at.to_date == date }
      moods = day_entries.map { |e| e.insights.dig('mood', 'score') }.compact
      avg_mood = moods.any? ? moods.sum.to_f / moods.size : nil
      
      next if day_entries.empty?
      
      {
        date: date,
        mood_score: avg_mood&.round(2),
        entries_count: day_entries.count
      }
    end.compact
  end

  def productivity_trends_data
    # Анализ продуктивности по дням недели
    entries = current_user.entries.active
                .where('created_at >= ?', 4.weeks.ago)

    productivity_by_weekday = entries.group_by { |e| e.created_at.strftime('%A') }
                                   .transform_values do |day_entries|
                                     {
                                       total_entries: day_entries.count,
                                       plans_count: day_entries.count { |e| e.plan? },
                                       ideas_count: day_entries.count { |e| e.idea? },
                                       diary_count: day_entries.count { |e| e.diary? }
                                     }
                                   end

    productivity_by_weekday
  end

  def category_distribution_data
    current_user.entries.active
      .group(:category)
      .count
  end

  def weekly_activity_data
    # Активность по неделям за последние 12 недель
    entries = current_user.entries.active.where('created_at >= ?', 12.weeks.ago)
    
    weeks_data = []
    12.times do |i|
      week_start = (12 - i).weeks.ago.beginning_of_week
      week_end = week_start.end_of_week
      week_entries = entries.select { |e| e.created_at >= week_start && e.created_at <= week_end }
      
      weeks_data << {
        week: week_start.strftime('%Y-W%U'),
        total_entries: week_entries.count,
        by_type: week_entries.group_by(&:entry_type).transform_values(&:count),
        avg_per_day: (week_entries.count / 7.0).round(1)
      }
    end
    
    weeks_data
  end

  def entry_types_over_time_data
    # Изменение типов записей за последние 6 месяцев
    entries = current_user.entries.active.where('created_at >= ?', 6.months.ago)
    
    months_data = []
    6.times do |i|
      month_start = (6 - i).months.ago.beginning_of_month
      month_end = month_start.end_of_month
      month_entries = entries.select { |e| e.created_at >= month_start && e.created_at <= month_end }
      
      months_data << {
        month: month_start.strftime('%Y-%m'),
        diary: month_entries.count(&:diary?),
        ideas: month_entries.count(&:idea?),
        plans: month_entries.count(&:plan?)
      }
    end
    
    months_data
  end

  def serialize_insight(insight)
    {
      id: insight.id,
      insight_type: insight.insight_type,
      title: insight.title,
      content: insight.content&.truncate(200),
      generated_at: insight.generated_at,
      expires_at: insight.expires_at,
      is_expired: insight.expired?
    }
  end

  def serialize_insight_full(insight)
    {
      id: insight.id,
      insight_type: insight.insight_type,
      title: insight.title,
      content: insight.content,
      data: insight.data,
      generated_at: insight.generated_at,
      expires_at: insight.expires_at,
      created_at: insight.created_at,
      is_expired: insight.expired?
    }
  end
end
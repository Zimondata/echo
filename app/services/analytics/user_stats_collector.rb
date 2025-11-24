class Analytics::UserStatsCollector
  attr_reader :user, :period

  def initialize(user, period = 1.week.ago..Time.current)
    @user = user
    @period = period
  end

  def self.daily_stats(user, date = Date.current)
    period = date.beginning_of_day..date.end_of_day
    new(user, period).collect_daily_stats
  end

  def self.weekly_stats(user, date = Date.current)
    period = date.beginning_of_week..date.end_of_week
    new(user, period).collect_weekly_stats
  end

  def self.monthly_stats(user, date = Date.current)
    period = date.beginning_of_month..date.end_of_month
    new(user, period).collect_monthly_stats
  end

  def collect_daily_stats
    entries = user.entries.where(created_at: period)
    events = user.calendar_events.where(start_time: period)

    {
      total_entries: entries.count,
      by_type: entries.group(:entry_type).count,
      by_category: entries.group(:category).count,
      events_count: events.count,
      completed_events: events.where(done: true).count,
      mood_keywords: extract_mood_keywords(entries),
      productivity_score: calculate_productivity_score(entries, events),
      top_themes: extract_top_themes(entries)
    }
  end

  def collect_weekly_stats
    entries = user.entries.where(created_at: period)
    events = user.calendar_events.where(start_time: period)

    {
      total_entries: entries.count,
      daily_breakdown: calculate_daily_breakdown(entries),
      top_categories: entries.group(:category).count.sort_by(&:last).reverse.first(3).to_h,
      productivity_score: calculate_productivity_score(entries, events),
      completion_rate: calculate_completion_rate(events),
      growth_metrics: calculate_growth_metrics(entries),
      time_patterns: analyze_time_patterns(entries),
      mood_trends: analyze_mood_trends(entries)
    }
  end

  def collect_monthly_stats
    entries = user.entries.where(created_at: period)
    events = user.calendar_events.where(start_time: period)

    {
      total_entries: entries.count,
      weekly_breakdown: calculate_weekly_breakdown(entries),
      category_trends: analyze_category_trends(entries),
      productivity_trends: analyze_productivity_trends(entries, events),
      goal_progress: analyze_goal_progress(entries),
      insights_generated: user.insights.where(generated_at: period).count
    }
  end

  private

  def calculate_daily_breakdown(entries)
    period.each_with_object({}) do |date, breakdown|
      day_entries = entries.where(created_at: date.beginning_of_day..date.end_of_day)
      breakdown[date.strftime('%Y-%m-%d')] = {
        count: day_entries.count,
        types: day_entries.group(:entry_type).count
      }
    end
  end

  def calculate_weekly_breakdown(entries)
    weeks = {}
    current = period.begin.beginning_of_week
    
    while current <= period.end
      week_end = [current.end_of_week, period.end].min
      week_entries = entries.where(created_at: current..week_end)
      
      weeks[current.strftime('%Y-W%U')] = {
        count: week_entries.count,
        productivity: calculate_productivity_score(week_entries, user.calendar_events.where(start_time: current..week_end))
      }
      
      current = current.next_week
    end
    
    weeks
  end

  def calculate_productivity_score(entries, events)
    base_score = 0

    # Очки за количество записей
    base_score += [entries.count * 5, 50].min

    # Очки за разнообразие типов записей
    unique_types = entries.distinct.count(:entry_type)
    base_score += unique_types * 10

    # Очки за выполненные события
    completed = events.where(done: true).count
    total_events = events.count
    if total_events > 0
      completion_rate = completed.to_f / total_events
      base_score += (completion_rate * 30).round
    end

    # Очки за планы и идеи
    plans_count = entries.where(entry_type: 'plan').count
    ideas_count = entries.where(entry_type: 'idea').count
    base_score += (plans_count * 3) + (ideas_count * 2)

    [base_score, 100].min
  end

  def calculate_completion_rate(events)
    return 0 if events.count == 0
    
    completed = events.where(done: true).count
    (completed.to_f / events.count * 100).round(1)
  end

  def calculate_growth_metrics(entries)
    current_week = entries.count
    previous_period = (period.begin - 1.week)..(period.begin)
    previous_week = user.entries.where(created_at: previous_period).count
    
    growth = previous_week > 0 ? ((current_week - previous_week).to_f / previous_week * 100).round(1) : 0
    
    {
      entries_growth: growth,
      consistency_score: calculate_consistency_score(entries)
    }
  end

  def calculate_consistency_score(entries)
    daily_counts = calculate_daily_breakdown(entries).values.map { |day| day[:count] }
    return 0 if daily_counts.empty?
    
    avg = daily_counts.sum.to_f / daily_counts.size
    variance = daily_counts.map { |count| (count - avg) ** 2 }.sum / daily_counts.size
    
    # Инвертированный коэффициент вариации (чем меньше разброс, тем выше консистентность)
    std_dev = Math.sqrt(variance)
    consistency = avg > 0 ? [100 - (std_dev / avg * 100), 0].max.round(1) : 0
    
    [consistency, 100].min
  end

  def analyze_time_patterns(entries)
    hours = entries.group_by { |entry| entry.created_at.hour }
    peak_hour = hours.max_by { |hour, entries| entries.count }&.first
    
    {
      peak_hour: peak_hour,
      morning_entries: entries.where(created_at: period.begin.change(hour: 6)..period.begin.change(hour: 12)).count,
      evening_entries: entries.where(created_at: period.begin.change(hour: 18)..period.begin.change(hour: 23)).count
    }
  end

  def analyze_mood_trends(entries)
    mood_keywords = extract_mood_keywords(entries)
    positive_words = %w[отлично хорошо прекрасно замечательно счастлив радостный позитивный]
    negative_words = %w[плохо грустно устал стресс проблема сложно трудно]
    
    positive_count = mood_keywords.count { |word| positive_words.include?(word.downcase) }
    negative_count = mood_keywords.count { |word| negative_words.include?(word.downcase) }
    
    {
      mood_score: calculate_mood_score(positive_count, negative_count),
      positive_indicators: positive_count,
      negative_indicators: negative_count,
      trending_emotions: mood_keywords.first(5)
    }
  end

  def calculate_mood_score(positive, negative)
    total = positive + negative
    return 50 if total == 0 # Нейтральное настроение
    
    score = (positive.to_f / total * 100).round
    [score, 100].min
  end

  def extract_mood_keywords(entries)
    content = entries.pluck(:content).join(' ')
    mood_words = content.downcase.scan(/\b(хорошо|плохо|отлично|устал|счастлив|грустно|радостный|стресс|позитив|проблема|успех|достижение)\b/)
    mood_words.flatten.uniq
  end

  def extract_top_themes(entries)
    content = entries.pluck(:content).join(' ')
    # Простое извлечение часто встречающихся слов (можно улучшить с помощью NLP)
    words = content.downcase.gsub(/[^\w\s]/, '').split
    
    # Исключаем служебные слова
    stop_words = %w[и или но а в на с по для от до при про под над между через]
    meaningful_words = words.reject { |word| stop_words.include?(word) || word.length < 3 }
    
    # Подсчитываем частоту
    word_freq = meaningful_words.each_with_object(Hash.new(0)) { |word, hash| hash[word] += 1 }
    
    # Возвращаем топ-5 тем
    word_freq.sort_by(&:last).reverse.first(5).map(&:first)
  end

  def analyze_category_trends(entries)
    entries.group(:category).group_by_week(:created_at).count
  end

  def analyze_productivity_trends(entries, events)
    weeks = {}
    current = period.begin.beginning_of_week
    
    while current <= period.end
      week_end = [current.end_of_week, period.end].min
      week_entries = entries.where(created_at: current..week_end)
      week_events = events.where(start_time: current..week_end)
      
      weeks[current.strftime('%Y-W%U')] = calculate_productivity_score(week_entries, week_events)
      current = current.next_week
    end
    
    weeks
  end

  def analyze_goal_progress(entries)
    goals = entries.where(entry_type: 'plan').where("content LIKE ? COLLATE NOCASE", "%цель%")
    completed_goals = goals.joins(:calendar_events).where(calendar_events: { done: true })
    
    {
      total_goals: goals.count,
      completed_goals: completed_goals.count,
      progress_rate: goals.count > 0 ? (completed_goals.count.to_f / goals.count * 100).round(1) : 0
    }
  end
end
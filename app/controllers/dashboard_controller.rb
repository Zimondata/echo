class DashboardController < ApplicationController
  # Helper method to convert hex color to rgba
  helper_method :hex_to_rgba
  
  def index
    @user = current_user
    return redirect_to login_path, alert: "Пожалуйста, войдите в систему" unless @user

    @zone = ActiveSupport::TimeZone[@user.timezone] || Time.zone
    @selected_date = params[:date].present? ? Date.iso8601(params[:date]) : Time.current.in_time_zone(@zone).to_date
    day_range = @zone.local(@selected_date.year, @selected_date.month, @selected_date.day).all_day

    @today_events = @user.calendar_events.active.for_date_range(day_range.begin, day_range.end).order(:start_time)
    @today_blocks = TimeBlock.active.joins(:task).merge(@user.tasks.active).where(starts_at: day_range).includes(:task).order(:starts_at)
    @timeline_items = (@today_events.to_a + @today_blocks.to_a).sort_by { |item| timeline_start(item) }
    @now_item = @user.tasks.active.where(status: %w[next scheduled]).order(Arel.sql("CASE WHEN due_on IS NULL THEN 1 ELSE 0 END"), :due_on, :created_at).first
    @needs_me = @user.tasks.active.where(status: %w[inbox waiting]).order(:created_at).limit(2)

    reference_time = @selected_date == Time.current.in_time_zone(@zone).to_date ? Time.current : day_range.begin
    @next_timed_event = @today_events.reject(&:all_day?).find { |event| timeline_end(event) > reference_time }

    @nutrition_entries = @user.nutrition_entries.active.where(recorded_at: day_range)
    @activity_entries = @user.activity_entries.active.where(activity_date: day_range)
    @nutrition_calories = @nutrition_entries.sum(:calories) if @nutrition_entries.any?
    @latest_activity = @activity_entries.order(activity_date: :desc).first

    @rhythms = @user.rhythms.active.ordered.includes(:rhythm_checkins)
    @rhythm_today = @rhythms.to_h do |rhythm|
      [ rhythm.id, rhythm.rhythm_checkins.find { |checkin| checkin.local_date == @selected_date } ]
    end
  rescue Date::Error
    redirect_to dashboard_path, alert: "Некорректная дата"
  end

  def nutrition_stats
    @user = current_user
    return render json: { calories: 0 } unless @user

    date = params[:date] ? Date.parse(params[:date]) : Date.current
    user_tz = ActiveSupport::TimeZone.new(@user.timezone || 'UTC')
    date_in_tz = user_tz.parse(date.to_s).to_date
    
    totals = NutritionEntry.daily_totals(@user, date_in_tz)
    
    render json: {
      calories: totals[:calories].to_i,
      protein: totals[:protein].to_f.round(1),
      fat: totals[:fat].to_f.round(1),
      carbs: totals[:carbs].to_f.round(1),
      meals_count: totals[:meals_count]
    }
  rescue => e
    Rails.logger.error "Dashboard nutrition_stats error: #{e.message}"
    render json: { calories: 0 }
  end


  private

  def timeline_start(item)
    item.is_a?(TimeBlock) ? item.starts_at : item.start_time
  end

  def timeline_end(item)
    return item.ends_at if item.is_a?(TimeBlock)

    item.end_time || item.start_time + 1.hour
  end

  def generate_ai_insights
    # Анализ активности за последнюю неделю
    week_events = @user.calendar_events.for_week(Date.current)
    recent_entries = @user.entries.where('created_at >= ?', 1.week.ago)
    
    # Определяем самый активный день недели
    events_by_day = week_events.group_by { |e| e.start_time.strftime('%A') }
    busiest_day = events_by_day.max_by { |day, events| events.count }&.first || 'Понедельник'
    busiest_day_count = events_by_day[busiest_day]&.count || 0

    # Анализ времени активности
    morning_events = week_events.select { |e| e.start_time.hour.between?(6, 11) }.count
    afternoon_events = week_events.select { |e| e.start_time.hour.between?(12, 17) }.count
    evening_events = week_events.select { |e| e.start_time.hour.between?(18, 23) }.count
    
    peak_time = if morning_events >= afternoon_events && morning_events >= evening_events
                  { period: 'утром', range: '6:00-11:00', emoji: '🌅' }
                elsif afternoon_events >= evening_events
                  { period: 'днем', range: '12:00-17:00', emoji: '☀️' }
                else
                  { period: 'вечером', range: '18:00-23:00', emoji: '🌙' }
                end

    # Анализ типов активности
    activity_types = recent_entries.group(:entry_type).count
    top_activity = activity_types.max_by { |type, count| count }&.first
    
    # Генерируем рекомендации
    recommendations = []
    
    if busiest_day_count > 3
      recommendations << "Заблокируйте время для фокусной работы в #{get_least_busy_day(events_by_day)}"
    end
    
    if week_events.where(done: false).count > 5
      recommendations << "У вас #{week_events.where(done: false).count} незавершенных задач - попробуйте завершить 2-3 сегодня"
    end
    
    if recent_entries.where(entry_type: 'idea').count > recent_entries.where(entry_type: 'plan').count * 2
      recommendations << "Много идей! Превратите 1-2 в конкретные планы"
    end

    # Мотивационные инсайты
    completed_tasks = week_events.where(done: true).count
    motivation = if completed_tasks >= 5
                   { text: "Отличная неделя! Вы завершили #{completed_tasks} задач", emoji: '🎉' }
                 elsif completed_tasks >= 2
                   { text: "Хороший прогресс - #{completed_tasks} завершенных задач", emoji: '💪' }
                 else
                   { text: "Время взяться за дела! Начните с малого", emoji: '🚀' }
                 end

    {
      peak_time: peak_time,
      busiest_day: { 
        name: translate_day(busiest_day), 
        count: busiest_day_count,
        emoji: '📅'
      },
      top_activity: {
        type: translate_activity(top_activity),
        count: activity_types[top_activity] || 0,
        emoji: get_activity_emoji(top_activity)
      },
      recommendations: recommendations.first(2), # Максимум 2 рекомендации
      motivation: motivation,
      week_progress: {
        completed: completed_tasks,
        total: week_events.count,
        percentage: week_events.count > 0 ? (completed_tasks.to_f / week_events.count * 100).round : 0
      }
    }
  end

  def get_least_busy_day(events_by_day)
    russian_days = {
      'Monday' => 'понедельник', 'Tuesday' => 'вторник', 'Wednesday' => 'среду',
      'Thursday' => 'четверг', 'Friday' => 'пятницу', 'Saturday' => 'субботу',
      'Sunday' => 'воскресенье'
    }
    
    least_busy = events_by_day.min_by { |day, events| events.count }&.first || 'Wednesday'
    russian_days[least_busy] || 'среду'
  end

  def translate_day(english_day)
    days = {
      'Monday' => 'Понедельник', 'Tuesday' => 'Вторник', 'Wednesday' => 'Среда',
      'Thursday' => 'Четверг', 'Friday' => 'Пятница', 'Saturday' => 'Суббота',
      'Sunday' => 'Воскресенье'
    }
    days[english_day] || english_day
  end

  def translate_activity(activity_type)
    types = {
      'diary' => 'дневниковые записи',
      'idea' => 'идеи',
      'plan' => 'планирование'
    }
    types[activity_type] || 'активность'
  end

  def get_activity_emoji(activity_type)
    emojis = {
      'diary' => '📔',
      'idea' => '💡',
      'plan' => '📋'
    }
    emojis[activity_type] || '✨'
  end
  
  def hex_to_rgba(hex_color, opacity = 0.2)
    # Remove # if present
    hex_color = hex_color.gsub('#', '')
    
    # Convert hex to RGB
    r = hex_color[0..1].to_i(16)
    g = hex_color[2..3].to_i(16) 
    b = hex_color[4..5].to_i(16)
    
    "rgba(#{r}, #{g}, #{b}, #{opacity})"
  end
end

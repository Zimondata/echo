class ActivityEntry < ApplicationRecord
  belongs_to :user

  # Validations
  validates :activity_type, presence: true, inclusion: { 
    in: %w[running cycling strength swimming walking hiking yoga other] 
  }
  validates :activity_date, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :distance_km, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :calories_burned, numericality: { greater_than: 0 }, allow_blank: true
  validates :average_heart_rate, numericality: { greater_than: 0, less_than: 300 }, allow_blank: true
  validates :max_heart_rate, numericality: { greater_than: 0, less_than: 300 }, allow_blank: true
  validates :effort_level, numericality: { in: 1..10 }, allow_blank: true
  validates :status, presence: true, inclusion: { in: %w[active archived deleted] }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :recent, -> { order(activity_date: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :today, -> { where(activity_date: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(activity_date: 1.week.ago.beginning_of_day..Date.current.end_of_day) }
  scope :this_month, -> { where(activity_date: 1.month.ago.beginning_of_day..Date.current.end_of_day) }

  # Activity type helpers
  def running?
    activity_type == 'running'
  end

  def cycling?
    activity_type == 'cycling'
  end

  def strength?
    activity_type == 'strength'
  end

  def cardio?
    %w[running cycling swimming].include?(activity_type)
  end

  # Display helpers
  def activity_emoji
    case activity_type
    when 'running' then '🏃‍♂️'
    when 'cycling' then '🚴‍♂️'
    when 'strength' then '🏋️‍♂️'
    when 'swimming' then '🏊‍♂️'
    when 'walking' then '🚶‍♂️'
    when 'hiking' then '🥾'
    when 'yoga' then '🧘‍♂️'
    else '🏃‍♂️'
    end
  end

  def activity_name
    case activity_type
    when 'running' then 'Бег'
    when 'cycling' then 'Велосипед'
    when 'strength' then 'Силовая'
    when 'swimming' then 'Плавание'
    when 'walking' then 'Ходьба'
    when 'hiking' then 'Пеший туризм'
    when 'yoga' then 'Йога'
    else activity_type.humanize
    end
  end

  def formatted_duration
    return '' unless duration_minutes

    hours = duration_minutes / 60
    minutes = duration_minutes % 60
    
    if hours > 0
      "#{hours}ч #{minutes}м"
    else
      "#{minutes}м"
    end
  end

  def formatted_distance
    return '' unless distance_km

    if distance_km >= 1
      "#{distance_km.round(2)} км"
    else
      "#{(distance_km * 1000).round(0)} м"
    end
  end

  def formatted_pace
    return average_pace if average_pace.present?
    return '' unless distance_km && duration_minutes && distance_km > 0

    # Calculate pace in minutes per km
    pace_minutes = duration_minutes / distance_km
    minutes = pace_minutes.to_i
    seconds = ((pace_minutes - minutes) * 60).round

    "#{minutes}:#{seconds.to_s.rjust(2, '0')}/км"
  end

  # Statistics methods
  def self.total_calories_for_user(user, period = :all)
    activities = user.activity_entries.active
    
    case period
    when :today then activities.today
    when :week then activities.this_week
    when :month then activities.this_month
    else activities
    end.sum(:calories_burned)
  end

  def self.total_duration_for_user(user, period = :all)
    activities = user.activity_entries.active
    
    case period
    when :today then activities.today
    when :week then activities.this_week
    when :month then activities.this_month
    else activities
    end.sum(:duration_minutes)
  end

  def self.total_distance_for_user(user, period = :all)
    activities = user.activity_entries.active.where.not(distance_km: nil)
    
    case period
    when :today then activities.today
    when :week then activities.this_week
    when :month then activities.this_month
    else activities
    end.sum(:distance_km)
  end

  # Soft delete
  def soft_delete!
    update!(status: 'deleted')
  end

  def archive!
    update!(status: 'archived')
  end

  def restore!
    update!(status: 'active')
  end
end

class CalendarEvent < ApplicationRecord
  # Associations
  belongs_to :entry, optional: true
  belongs_to :user

  # Enums
  enum :priority, { low: 'low', medium: 'medium', high: 'high', urgent: 'urgent' }
  
  # Categories mapping
  CATEGORIES = {
    'diary' => { color: '#10B981', label: 'Дневник' },
    'idea' => { color: '#3B82F6', label: 'Идея' },
    'plan' => { color: '#8B5CF6', label: 'План' },
    'reminder' => { color: '#DC2626', label: '🔔 Напоминание' },
    'meeting' => { color: '#EF4444', label: 'Встреча' },
    'task' => { color: '#6B7280', label: 'Задача' }
  }.freeze

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :start_time, presence: true
  validates :event_type, inclusion: { in: CATEGORIES.keys }
  validates :priority, inclusion: { in: priorities.keys }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
  validate :end_time_after_start_time

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :upcoming, -> { active.where("start_time >= ?", Time.current).order(:start_time) }
  scope :past, -> { active.where("start_time < ?", Time.current).order(start_time: :desc) }
  scope :completed, -> { active.where(done: true) }
  scope :pending, -> { active.where(done: false) }
  scope :for_date_range, ->(start_date, end_date) {
    start_datetime = start_date.is_a?(Date) ? start_date.beginning_of_day : start_date
    end_datetime = end_date.is_a?(Date) ? end_date.end_of_day : end_date
    active.where("start_time <= ? AND (end_time >= ? OR end_time IS NULL)", end_datetime, start_datetime)
  }
  scope :by_category, ->(category) { active.where(event_type: category) }
  scope :with_reminders, -> { active.where.not(reminder_minutes: nil) }
  scope :reminder_pending, -> {
    active.where(reminder_sent: false)
          .where.not(reminder_minutes: nil)
          .where("start_time - INTERVAL '1 minute' * reminder_minutes <= ?", Time.current)
  }

  # Callbacks
  before_save :set_default_color
  before_save :set_end_time_for_all_day

  # Methods
  def category_info
    CATEGORIES[event_type] || CATEGORIES['task']
  end

  def display_color
    color.presence || category_info[:color]
  end

  def duration
    return 1.day if all_day?
    return 1.hour unless end_time
    end_time - start_time
  end

  def duration_minutes
    return nil unless end_time
    ((end_time - start_time) / 60).to_i
  end

  def start_date
    start_time.to_date
  end

  def end_date
    (end_time || start_time).to_date
  end

  def spans_multiple_days?
    start_date != end_date
  end

  def reminder_time
    return nil unless reminder_minutes
    start_time - reminder_minutes.minutes
  end

  def should_remind?
    reminder_minutes.present? && !reminder_sent? && !done?
  end

  def mark_reminder_sent!
    update!(reminder_sent: true)
  end

  def toggle_done!
    update!(done: !done?)
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def time_display(timezone = "UTC")
    return "Утром" if all_day? && title.downcase.include?("утр")
    return "Днем" if all_day? && title.downcase.include?("днем")
    return "Вечером" if all_day? && title.downcase.include?("вечер")
    return "Весь день" if all_day?
    start_time.in_time_zone(timezone).strftime("%H:%M")
  end

  # Class methods
  def self.for_week(date = Date.current)
    start_of_week = date.beginning_of_week(:monday)
    end_of_week = date.end_of_week(:monday)
    for_date_range(start_of_week, end_of_week)
  end

  def self.for_month(date = Date.current)
    start_of_month = date.beginning_of_month
    end_of_month = date.end_of_month
    for_date_range(start_of_month, end_of_month)
  end

  private

  def set_default_color
    self.color ||= category_info[:color]
  end

  def set_end_time_for_all_day
    if all_day? && end_time.blank?
      self.end_time = start_time.end_of_day
    end
  end

  def end_time_after_start_time
    return unless end_time && start_time
    return if all_day? # All-day events can end on the same day
    
    if end_time <= start_time
      errors.add(:end_time, 'должно быть после времени начала')
    end
  end
end

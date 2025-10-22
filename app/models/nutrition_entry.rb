class NutritionEntry < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :entry, optional: true

  # Validations
  validates :meal_type, presence: true, inclusion: { in: %w[breakfast lunch dinner snack] }
  validates :calories, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :protein, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fat, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :carbs, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :recorded_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[active deleted] }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :for_date, ->(date) { where('DATE(recorded_at) = ?', date) }
  scope :for_date_range, ->(start_date, end_date) { where(recorded_at: start_date.beginning_of_day..end_date.end_of_day) }
  scope :recent, -> { order(recorded_at: :desc) }
  scope :by_meal_type, ->(type) { where(meal_type: type) }
  scope :breakfast, -> { where(meal_type: 'breakfast') }
  scope :lunch, -> { where(meal_type: 'lunch') }
  scope :dinner, -> { where(meal_type: 'dinner') }
  scope :snacks, -> { where(meal_type: 'snack') }

  # Callbacks
  before_validation :set_recorded_at, on: :create

  # Methods
  def total_macros
    protein + fat + carbs
  end

  def calories_from_macros
    (protein * 4) + (fat * 9) + (carbs * 4)
  end

  def macro_percentages
    total = total_macros
    return { protein: 0, fat: 0, carbs: 0 } if total.zero?

    {
      protein: ((protein / total) * 100).round(1),
      fat: ((fat / total) * 100).round(1),
      carbs: ((carbs / total) * 100).round(1)
    }
  end

  def meal_type_display
    {
      'breakfast' => 'Завтрак',
      'lunch' => 'Обед',
      'dinner' => 'Ужин',
      'snack' => 'Перекус'
    }[meal_type] || meal_type.capitalize
  end

  def food_items_list
    return [] if food_items.blank?
    
    food_items.split(',').map(&:strip)
  end

  def has_photo?
    photo_url.present?
  end

  def analysis_summary
    return {} if analysis_data.blank?
    
    analysis_data.with_indifferent_access
  end

  # Class methods for statistics
  def self.daily_totals(user, date)
    entries = active.where(user: user).for_date(date)
    
    {
      calories: entries.sum(:calories),
      protein: entries.sum(:protein),
      fat: entries.sum(:fat),
      carbs: entries.sum(:carbs),
      meals_count: entries.count
    }
  end

  def self.weekly_averages(user, start_date = 1.week.ago.to_date)
    end_date = start_date + 6.days
    entries = active.where(user: user).for_date_range(start_date, end_date)
    days_count = 7

    {
      avg_calories: (entries.sum(:calories) / days_count).round(0),
      avg_protein: (entries.sum(:protein) / days_count).round(1),
      avg_fat: (entries.sum(:fat) / days_count).round(1),
      avg_carbs: (entries.sum(:carbs) / days_count).round(1),
      total_meals: entries.count
    }
  end

  private

  def set_recorded_at
    self.recorded_at ||= Time.current
  end
end

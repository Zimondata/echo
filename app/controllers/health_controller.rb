class HealthController < ApplicationController
  class InvalidLocalTime < StandardError; end

  def show
    zone = owner_zone
    @today = Time.current.in_time_zone(zone).to_date
    day_start = zone.local(@today.year, @today.month, @today.day)
    day_range = day_start..day_start.end_of_day

    @nutrition_entries = current_user.nutrition_entries.active.where(recorded_at: day_range).order(recorded_at: :desc)
    @activity_entries = current_user.activity_entries.active.where(activity_date: day_range).order(activity_date: :desc)
    @nutrition_totals = nutrition_summary(@nutrition_entries)
    @activity_totals = activity_summary(@activity_entries)
  end

  def new_nutrition
    @nutrition_entry = current_user.nutrition_entries.build(recorded_at: owner_now, meal_type: "breakfast")
  end

  def create_nutrition
    @nutrition_entry = current_user.nutrition_entries.build(nutrition_params.except(:recorded_at))
    @nutrition_entry.recorded_at = parse_owner_wall_clock(nutrition_params[:recorded_at])

    if @nutrition_entry.save
      redirect_to health_path, notice: "Питание записано локально."
    else
      render :new_nutrition, status: :unprocessable_entity
    end
  rescue InvalidLocalTime
    @nutrition_entry ||= current_user.nutrition_entries.build(nutrition_params.except(:recorded_at))
    @nutrition_entry.errors.add(:recorded_at, "не существует в выбранном часовом поясе")
    render :new_nutrition, status: :unprocessable_entity
  end

  def new_activity
    @activity_entry = current_user.activity_entries.build(activity_date: owner_now, activity_type: "walking")
  end

  def create_activity
    @activity_entry = current_user.activity_entries.build(activity_params.except(:activity_date))
    @activity_entry.activity_date = parse_owner_wall_clock(activity_params[:activity_date])

    if @activity_entry.save
      redirect_to health_path, notice: "Активность записана локально."
    else
      render :new_activity, status: :unprocessable_entity
    end
  rescue InvalidLocalTime
    @activity_entry ||= current_user.activity_entries.build(activity_params.except(:activity_date))
    @activity_entry.errors.add(:activity_date, "не существует в выбранном часовом поясе")
    render :new_activity, status: :unprocessable_entity
  end

  private

  def owner_zone
    Time.find_zone!(current_user.timezone)
  end

  def owner_now
    Time.current.in_time_zone(owner_zone)
  end

  def parse_owner_wall_clock(value)
    parsed = DateTime.strptime(value.to_s, "%Y-%m-%dT%H:%M")
    local = owner_zone.local(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute)
    raise InvalidLocalTime unless local.strftime("%Y-%m-%dT%H:%M") == value.to_s

    local
  rescue ArgumentError
    raise InvalidLocalTime
  end

  def nutrition_params
    params.require(:nutrition_entry).permit(:meal_type, :meal_description, :food_items, :calories, :protein, :fat, :carbs, :recorded_at)
  end

  def activity_params
    params.require(:activity_entry).permit(:activity_type, :duration_minutes, :distance_km, :calories_burned, :activity_date, :notes)
  end

  def nutrition_summary(entries)
    return nil if entries.empty?

    {
      meals_count: entries.size,
      calories: entries.sum { |entry| entry.calories.to_f },
      protein: entries.sum { |entry| entry.protein.to_f },
      fat: entries.sum { |entry| entry.fat.to_f },
      carbs: entries.sum { |entry| entry.carbs.to_f }
    }
  end

  def activity_summary(entries)
    return nil if entries.empty?

    distances = entries.filter_map(&:distance_km)
    calories = entries.filter_map(&:calories_burned)
    {
      activity_count: entries.size,
      duration: entries.sum { |entry| entry.duration_minutes.to_i },
      distance: distances.any? ? distances.sum : nil,
      calories: calories.any? ? calories.sum : nil
    }
  end
end

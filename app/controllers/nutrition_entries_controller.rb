class NutritionEntriesController < ApplicationController
  before_action :set_nutrition_entry, only: [:show, :edit, :update, :destroy]
  before_action :ensure_current_user

  def index
    @user = current_user
    @today = Date.current
    @selected_date = params[:date] ? Date.parse(params[:date]) : @today
    
    # Get nutrition entries for selected date
    @nutrition_entries = @user.nutrition_entries.active
                              .for_date(@selected_date)
                              .recent
                              .includes(:entry)

    # Calculate daily totals
    @daily_totals = NutritionEntry.daily_totals(@user, @selected_date)
    
    # Calculate weekly averages
    week_start = @selected_date.beginning_of_week
    @weekly_averages = NutritionEntry.weekly_averages(@user, week_start)

    # Group entries by meal type
    @meals = {
      'breakfast' => @nutrition_entries.breakfast,
      'lunch' => @nutrition_entries.lunch,
      'dinner' => @nutrition_entries.dinner,
      'snack' => @nutrition_entries.snacks
    }

    # Recent nutrition entries for quick view
    @recent_entries = @user.nutrition_entries.active.recent.limit(5)
    
    # Activity data for the day
    @activity_entries = @user.activity_entries.active
                             .where(activity_date: @selected_date.beginning_of_day..@selected_date.end_of_day)
                             .recent
    
    # Activity totals for the day
    @activity_totals = {
      total_duration: @activity_entries.sum(:duration_minutes),
      total_calories_burned: @activity_entries.sum(:calories_burned),
      total_distance: @activity_entries.sum(:distance_km),
      activity_count: @activity_entries.count
    }
    
    # AI analysis of the day (only if we have data)
    if @nutrition_entries.any? || @activity_entries.any?
      @daily_analysis = Ai::DailyHealthAnalyzer.analyze_day(@user, @selected_date)
    else
      @daily_analysis = nil
    end
    
    # Calendar dates with nutrition data
    @calendar_dates = generate_calendar_dates(@selected_date)
  end

  def show
    @daily_totals = NutritionEntry.daily_totals(current_user, @nutrition_entry.recorded_at.to_date)
  end

  def new
    @nutrition_entry = current_user.nutrition_entries.build
    @nutrition_entry.recorded_at = Time.current
    @selected_meal_type = params[:meal_type] || 'breakfast'
  end

  def create
    @nutrition_entry = current_user.nutrition_entries.build(nutrition_entry_params)
    
    if @nutrition_entry.save
      redirect_to nutrition_entries_path, notice: 'Запись о питании успешно добавлена!'
    else
      @selected_meal_type = @nutrition_entry.meal_type
      render :new
    end
  end

  def edit
  end

  def update
    if @nutrition_entry.update(nutrition_entry_params)
      redirect_to nutrition_entries_path, notice: 'Запись о питании обновлена!'
    else
      render :edit
    end
  end

  def destroy
    return unless @nutrition_entry # Guard clause in case entry not found
    
    if @nutrition_entry.update(status: 'deleted')
      respond_to do |format|
        format.html { redirect_to nutrition_entries_path, notice: 'Запись о питании удалена!' }
        format.json { render json: { success: true, message: 'Запись о питании удалена' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to nutrition_entries_path, alert: 'Ошибка при удалении записи' }
        format.json { render json: { success: false, error: 'Ошибка при удалении записи' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_nutrition_entry
    @nutrition_entry = current_user.nutrition_entries.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to nutrition_entries_path, alert: 'Запись не найдена' }
      format.json { render json: { success: false, error: 'Запись не найдена' }, status: :not_found }
    end
  end

  def nutrition_entry_params
    params.require(:nutrition_entry).permit(
      :calories, :protein, :fat, :carbs, :meal_type, 
      :food_items, :recorded_at, :meal_description, :photo_url
    )
  end

  def ensure_current_user
    redirect_to login_path, alert: 'Пожалуйста, войдите в систему' unless current_user
  end

  def generate_calendar_dates(selected_date)
    start_date = selected_date.beginning_of_month.beginning_of_week
    end_date = selected_date.end_of_month.end_of_week
    
    nutrition_counts = current_user.nutrition_entries.active
                                  .where(recorded_at: start_date..end_date)
                                  .group("DATE(recorded_at)")
                                  .count

    (start_date..end_date).map do |date|
      {
        date: date,
        nutrition_count: nutrition_counts[date.to_s] || 0,
        is_today: date == Date.current,
        is_selected: date == selected_date,
        is_current_month: date.month == selected_date.month
      }
    end
  end
end
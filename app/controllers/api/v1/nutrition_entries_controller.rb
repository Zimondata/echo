class Api::V1::NutritionEntriesController < Api::BaseController
  before_action :set_nutrition_entry, only: [:show, :update, :destroy, :toggle_status]

  def index
    date = params[:date] ? Date.parse(params[:date]) : Date.current
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : nil
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : nil

    entries = current_user.nutrition_entries.active.includes(:entry)

    if start_date && end_date
      entries = entries.for_date_range(start_date, end_date)
    elsif date
      entries = entries.for_date(date)
    end

    entries = entries.recent

    render json: {
      success: true,
      data: entries.map do |entry|
        entry_data(entry)
      end,
      meta: {
        total: entries.count,
        date: date,
        daily_totals: start_date && end_date ? nil : NutritionEntry.daily_totals(current_user, date)
      }
    }
  end

  def show
    render json: {
      success: true,
      data: entry_data(@nutrition_entry)
    }
  end

  def create
    @nutrition_entry = current_user.nutrition_entries.build(nutrition_entry_params)

    if @nutrition_entry.save
      render json: {
        success: true,
        data: entry_data(@nutrition_entry),
        message: 'Запись о питании создана'
      }, status: :created
    else
      render json: {
        success: false,
        errors: @nutrition_entry.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @nutrition_entry.update(nutrition_entry_params)
      render json: {
        success: true,
        data: entry_data(@nutrition_entry),
        message: 'Запись о питании обновлена'
      }
    else
      render json: {
        success: false,
        errors: @nutrition_entry.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @nutrition_entry.update(status: 'deleted')
    render json: {
      success: true,
      message: 'Запись о питании удалена'
    }
  end

  def toggle_status
    new_status = @nutrition_entry.status == 'active' ? 'deleted' : 'active'
    @nutrition_entry.update(status: new_status)
    
    render json: {
      success: true,
      data: entry_data(@nutrition_entry)
    }
  end

  def daily_stats
    date = params[:date] ? Date.parse(params[:date]) : Date.current
    stats = NutritionEntry.daily_totals(current_user, date)
    
    entries = current_user.nutrition_entries.active.for_date(date)
    meals_by_type = {
      'breakfast' => entries.breakfast.count,
      'lunch' => entries.lunch.count,
      'dinner' => entries.dinner.count,
      'snack' => entries.snacks.count
    }

    render json: {
      success: true,
      data: {
        date: date,
        totals: stats,
        meals_by_type: meals_by_type,
        macro_percentages: calculate_macro_percentages(stats)
      }
    }
  end

  def weekly_stats
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 1.week.ago.to_date
    stats = NutritionEntry.weekly_averages(current_user, start_date)
    
    # Daily breakdown for the week
    daily_breakdown = (start_date..start_date + 6.days).map do |date|
      daily_stats = NutritionEntry.daily_totals(current_user, date)
      {
        date: date,
        **daily_stats
      }
    end

    render json: {
      success: true,
      data: {
        start_date: start_date,
        end_date: start_date + 6.days,
        averages: stats,
        daily_breakdown: daily_breakdown
      }
    }
  end

  def monthly_stats
    date = params[:date] ? Date.parse(params[:date]) : Date.current
    start_date = date.beginning_of_month
    end_date = date.end_of_month
    
    entries = current_user.nutrition_entries.active.for_date_range(start_date, end_date)
    days_count = (end_date - start_date + 1).to_i
    
    monthly_totals = {
      calories: entries.sum(:calories),
      protein: entries.sum(:protein),
      fat: entries.sum(:fat),
      carbs: entries.sum(:carbs),
      meals_count: entries.count
    }
    
    monthly_averages = {
      avg_calories: (monthly_totals[:calories] / days_count).round(0),
      avg_protein: (monthly_totals[:protein] / days_count).round(1),
      avg_fat: (monthly_totals[:fat] / days_count).round(1),
      avg_carbs: (monthly_totals[:carbs] / days_count).round(1)
    }

    render json: {
      success: true,
      data: {
        month: date.strftime('%B %Y'),
        start_date: start_date,
        end_date: end_date,
        totals: monthly_totals,
        averages: monthly_averages,
        days_count: days_count
      }
    }
  end

  private

  def set_nutrition_entry
    @nutrition_entry = current_user.nutrition_entries.find(params[:id])
  end

  def nutrition_entry_params
    params.require(:nutrition_entry).permit(
      :calories, :protein, :fat, :carbs, :meal_type,
      :food_items, :recorded_at, :meal_description, :photo_url,
      analysis_data: {}
    )
  end

  def entry_data(nutrition_entry)
    {
      id: nutrition_entry.id,
      calories: nutrition_entry.calories,
      protein: nutrition_entry.protein,
      fat: nutrition_entry.fat,
      carbs: nutrition_entry.carbs,
      meal_type: nutrition_entry.meal_type,
      meal_type_display: nutrition_entry.meal_type_display,
      food_items: nutrition_entry.food_items,
      food_items_list: nutrition_entry.food_items_list,
      recorded_at: nutrition_entry.recorded_at,
      meal_description: nutrition_entry.meal_description,
      photo_url: nutrition_entry.photo_url,
      has_photo: nutrition_entry.has_photo?,
      analysis_data: nutrition_entry.analysis_summary,
      macro_percentages: nutrition_entry.macro_percentages,
      total_macros: nutrition_entry.total_macros,
      calories_from_macros: nutrition_entry.calories_from_macros,
      status: nutrition_entry.status,
      created_at: nutrition_entry.created_at,
      updated_at: nutrition_entry.updated_at
    }
  end

  def calculate_macro_percentages(stats)
    total_macros = stats[:protein] + stats[:fat] + stats[:carbs]
    return { protein: 0, fat: 0, carbs: 0 } if total_macros.zero?

    {
      protein: ((stats[:protein] / total_macros) * 100).round(1),
      fat: ((stats[:fat] / total_macros) * 100).round(1),
      carbs: ((stats[:carbs] / total_macros) * 100).round(1)
    }
  end
end
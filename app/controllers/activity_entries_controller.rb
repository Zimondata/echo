class ActivityEntriesController < ApplicationController
  before_action :set_activity_entry, only: [:show, :edit, :update, :destroy]
  before_action :ensure_current_user

  def index
    @activity_entries = current_user.activity_entries.active.recent.includes(:user)
    @selected_date = params[:date] ? Date.parse(params[:date]) : Date.current
    
    # Filter by date if specified
    if params[:date]
      @activity_entries = @activity_entries.where(
        activity_date: @selected_date.beginning_of_day..@selected_date.end_of_day
      )
    end
  end

  def show
    # Activity entry is set by before_action
  end

  def new
    @activity_entry = current_user.activity_entries.build
    @activity_entry.activity_date = Time.current
    
    # Pre-fill activity type if provided
    if params[:activity_type].present?
      @activity_entry.activity_type = params[:activity_type]
    end
  end

  def create
    @activity_entry = current_user.activity_entries.build(activity_entry_params)
    
    if @activity_entry.save
      redirect_to nutrition_entries_path, notice: 'Тренировка успешно добавлена!'
    else
      render :new
    end
  end

  def edit
    # Activity entry is set by before_action
  end

  def update
    if @activity_entry.update(activity_entry_params)
      respond_to do |format|
        format.html { redirect_to nutrition_entries_path, notice: 'Тренировка обновлена!' }
        format.json { render json: { success: true, message: 'Тренировка обновлена' } }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: { success: false, errors: @activity_entry.errors.full_messages } }
      end
    end
  end

  def destroy
    return unless @activity_entry # Guard clause in case entry not found
    
    if @activity_entry.soft_delete!
      respond_to do |format|
        format.html { redirect_to nutrition_entries_path, notice: 'Тренировка удалена!' }
        format.json { render json: { success: true, message: 'Тренировка удалена' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to nutrition_entries_path, alert: 'Ошибка при удалении тренировки' }
        format.json { render json: { success: false, error: 'Ошибка при удалении тренировки' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_activity_entry
    @activity_entry = current_user.activity_entries.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to nutrition_entries_path, alert: 'Тренировка не найдена' }
      format.json { render json: { success: false, error: 'Тренировка не найдена' }, status: :not_found }
    end
  end

  def activity_entry_params
    params.require(:activity_entry).permit(
      :activity_type, :duration_minutes, :distance_km, :calories_burned,
      :average_heart_rate, :max_heart_rate, :average_pace, :activity_date,
      :notes, :effort_level
    )
  end

  def ensure_current_user
    redirect_to login_path, alert: 'Пожалуйста, войдите в систему' unless current_user
  end
end

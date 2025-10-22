class EntriesController < ApplicationController
  before_action :set_entry, only: [:show, :destroy]

  def index
    @entries = current_user.entries.active.order(created_at: :desc).limit(20)
  end

  def show
    # Entry is set by before_action
  end

  def diary
    @user = current_user
    @entries = current_user.entries.active.where(entry_type: "diary").order(created_at: :desc).limit(50)
    render :diary
  end

  def ideas
    @user = current_user
    @entries = current_user.entries.active.where(entry_type: "idea").parent_entries.order(created_at: :desc).limit(20)
    render :ideas
  end

  def plans
    @entries = current_user.entries.active.where(entry_type: "plan").order(created_at: :desc).limit(20)
    render :index
  end

  def destroy
    return unless @entry # Guard clause in case entry not found
    
    if @entry.update(status: 'deleted')
      respond_to do |format|
        format.html { redirect_to entries_diary_path, notice: 'Запись удалена' }
        format.json { render json: { success: true, message: 'Запись удалена' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to entries_diary_path, alert: 'Ошибка при удалении записи' }
        format.json { render json: { success: false, error: 'Ошибка при удалении записи' }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_entry
    @entry = current_user.entries.active.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to entries_path, alert: 'Запись не найдена' }
      format.json { render json: { success: false, error: 'Запись не найдена' }, status: :not_found }
    end
  end
end

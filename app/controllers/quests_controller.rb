class QuestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_quest, only: [:show, :edit, :update, :destroy, :toggle_step, :complete_step, :uncomplete_step, :update_status]

  def index
    @quests = current_user.quests.includes(:entry)
                         .order(created_at: :desc)
    
    # Filter by status if provided
    if params[:status].present?
      @quests = @quests.where(status: params[:status])
    end

    @stats = calculate_quest_stats
  end

  def show
    @entry = @quest.entry
    @checklist = @quest.checklist
    @progress = @quest.completion_percentage
  end

  def edit
    # For editing quest details
  end

  def update
    if @quest.update(quest_params)
      redirect_to @quest, notice: 'Квест успешно обновлен'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quest.destroy!
    redirect_to quests_path, notice: 'Квест удален'
  end

  def toggle_step
    step_id = params[:step_id]
    
    if @quest.toggle_step(step_id)
      render json: { 
        success: true, 
        completed: @quest.checklist.find { |s| s['id'] == step_id.to_i }['completed'],
        progress: @quest.completion_percentage,
        message: 'Статус задачи обновлен'
      }
    else
      render json: { success: false, message: 'Не удалось обновить статус задачи' }
    end
  end

  def complete_step
    step_id = params[:step_id]
    
    if @quest.complete_step(step_id)
      render json: { 
        success: true, 
        progress: @quest.completion_percentage,
        message: 'Задача отмечена как выполненная'
      }
    else
      render json: { success: false, message: 'Не удалось отметить задачу' }
    end
  end

  def uncomplete_step
    step_id = params[:step_id]
    
    if @quest.uncomplete_step(step_id)
      render json: { 
        success: true, 
        progress: @quest.completion_percentage,
        message: 'Задача отмечена как невыполненная'
      }
    else
      render json: { success: false, message: 'Не удалось снять отметку с задачи' }
    end
  end

  def update_status
    new_status = params[:new_status]
    
    if %w[active paused completed cancelled].include?(new_status)
      @quest.update!(status: new_status)
      redirect_to @quest, notice: "Статус квеста изменен на '#{@quest.status_display}'"
    else
      redirect_to @quest, alert: 'Некорректный статус'
    end
  end

  private

  def set_quest
    @quest = current_user.quests.find(params[:id])
  end

  def quest_params
    params.require(:quest).permit(:title, :description, :status, :priority, :due_date)
  end

  def calculate_quest_stats
    quests = current_user.quests
    
    {
      total: quests.count,
      active: quests.where(status: 'active').count,
      completed: quests.where(status: 'completed').count,
      paused: quests.where(status: 'paused').count,
      cancelled: quests.where(status: 'cancelled').count,
      high_priority: quests.where('priority >= ?', 7).count,
      overdue: quests.overdue.count,
      avg_completion: quests.where(status: 'active').average(:completion_rate)&.round || 0
    }
  end
end
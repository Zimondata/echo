class Api::V1::RemindersController < Api::BaseController
  before_action :find_reminder, only: [:show, :update, :destroy]
  
  def index
    @reminders = current_user.reminders.includes(:entry)
    render json: { reminders: @reminders }
  end

  def show
    render json: { 
      reminder: {
        id: @reminder.id,
        message: @reminder.message,
        remind_at: @reminder.remind_at.iso8601,
        status: @reminder.status,
        reminder_type: @reminder.reminder_type,
        created_at: @reminder.created_at.iso8601,
        updated_at: @reminder.updated_at.iso8601
      }
    }
  end

  def create
    @reminder = current_user.reminders.build(reminder_params)
    
    if @reminder.save
      render json: { 
        reminder: {
          id: @reminder.id,
          message: @reminder.message,
          remind_at: @reminder.remind_at.iso8601,
          status: @reminder.status
        }
      }, status: :created
    else
      render json: { errors: @reminder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @reminder.update(reminder_params)
      render json: { 
        reminder: {
          id: @reminder.id,
          message: @reminder.message,
          remind_at: @reminder.remind_at.iso8601,
          status: @reminder.status
        }
      }
    else
      render json: { errors: @reminder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @reminder.destroy
    render json: { message: 'Напоминание удалено' }
  end

  private

  def find_reminder
    @reminder = current_user.reminders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Напоминание не найдено' }, status: :not_found
  end

  def reminder_params
    params[:reminder_type] ||= 'one_time' # Default to one_time
    params.permit(:message, :remind_at, :reminder_type, :user_id, :entry_id)
  end
end
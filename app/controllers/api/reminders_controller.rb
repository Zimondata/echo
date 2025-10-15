class Api::RemindersController < ApplicationController
  before_action :find_reminder, only: [:send_now]
  
  def send_now
    if @reminder.status == 'sent'
      render json: { error: 'Напоминание уже отправлено' }, status: :unprocessable_entity
      return
    end

    begin
      # Send via Telegram
      bot_service = Telegram::BotService.instance
      bot_service.send_message(@reminder.user.telegram_id, @reminder.message)
      
      # Update reminder status
      @reminder.update!(
        status: 'sent',
        sent_at: Time.current
      )
      
      render json: { 
        success: true, 
        message: 'Напоминание отправлено',
        reminder: {
          id: @reminder.id,
          status: @reminder.status,
          sent_at: @reminder.sent_at
        }
      }
    rescue => e
      Rails.logger.error "Failed to send reminder #{@reminder.id}: #{e.message}"
      render json: { error: 'Ошибка при отправке напоминания' }, status: :internal_server_error
    end
  end

  private

  def find_reminder
    @reminder = Reminder.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Напоминание не найдено' }, status: :not_found
  end
end
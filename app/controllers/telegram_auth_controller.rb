class TelegramAuthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  # POST /telegram_auth/initiate
  def initiate
    result = TelegramAuthService.initiate_auth(
      ip: request.remote_ip,
      user_agent: request.user_agent
    )

    render json: result, status: :created
  end

  # POST /telegram_auth/status
  def status
    token = params[:session_token]
    session = TelegramAuthSession.find_by(session_token: token)

    if session.nil?
      Rails.logger.warn "Telegram auth status: session not found"
      render json: { 
        status: 'not_found',
        error: 'Session not found',
        message: 'Авторизация не найдена или устарела' 
      }, status: :not_found
      return
    end

    Rails.logger.info "Auth session found: #{session.status}, expires: #{session.expires_at}"

    if session.expired?
      Rails.logger.warn "Telegram auth status: session expired"
      session.expire!
      render json: { 
        status: 'expired', 
        message: 'Время авторизации истекло. Попробуйте снова.'
      }, status: :gone
    elsif session.status == 'confirmed'
      Rails.logger.info "Auth session confirmed for user: #{session.user_id}"
      render json: {
        status: 'confirmed',
        user_id: session.user_id,
        redirect_url: calendar_events_path(view: "month"),
        message: 'Авторизация успешна!'
      }
    elsif session.status == 'pending'
      Rails.logger.info "Telegram auth status: pending"
      render json: { 
        status: 'pending',
        message: 'Ожидание подтверждения в Telegram'
      }
    else
      Rails.logger.warn "Auth session in unknown state: #{session.status}"
      render json: { 
        status: 'error',
        message: 'Неизвестное состояние авторизации'
      }, status: :unprocessable_entity
    end
  end
end

class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :complete_telegram_auth]
  layout false, only: [:new]

  def new
    redirect_to dashboard_path if current_user

    # Check if there's an active session in the last 10 minutes
    # This prevents creating a new session on every page refresh
    session_token = session[:pending_auth_token]
    @auth_data = nil

    if session_token
      existing_session = TelegramAuthSession.active.find_by(session_token: session_token)
      if existing_session
        @auth_data = {
          session_token: existing_session.session_token,
          deep_link: TelegramAuthService.generate_deep_link(existing_session.session_token),
          qr_data: TelegramAuthService.generate_qr_data(existing_session.session_token),
          expires_at: existing_session.expires_at
        }
      end
    end

    # Only create new session if we don't have a valid one
    unless @auth_data
      @auth_data = TelegramAuthService.initiate_auth(
        ip: request.remote_ip,
        user_agent: request.user_agent
      )
      # Store token in session to reuse on refresh
      session[:pending_auth_token] = @auth_data[:session_token]
    end
  end
  
  def create
    # Development login (only in development mode)
    if Rails.env.development?
      user = User.find_by(telegram_id: params[:telegram_id]) || 
             User.first || 
             User.create!(
               telegram_id: params[:telegram_id] || "12345",
               username: params[:username] || "test_user",
               first_name: params[:first_name] || "Test",
               last_name: params[:last_name] || "User",
               timezone: 'Europe/Madrid',
               language: 'ru'
             )
      
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: 'Успешно вошли в систему!'
    else
      redirect_to root_path, alert: 'Недоступно в продакшене'
    end
  end
  
  def complete_telegram_auth
    token = params[:session_token]
    auth_session = TelegramAuthSession.confirmed.find_by(session_token: token)

    if auth_session&.user
      session[:user_id] = auth_session.user.id
      # Clear pending auth token since we successfully logged in
      session.delete(:pending_auth_token)
      
      # Handle different request types
      if request.post?
        render json: { success: true, redirect_url: dashboard_path }
      else
        redirect_to dashboard_path, notice: 'Успешно вошли в систему через Telegram!'
      end
    else
      if request.post?
        render json: { error: 'Invalid or expired session' }, status: :unauthorized
      else
        redirect_to login_path, alert: 'Недействительная или истёкшая сессия авторизации'
      end
    end
  end
  
  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: 'Вы вышли из системы'
  end
  
end
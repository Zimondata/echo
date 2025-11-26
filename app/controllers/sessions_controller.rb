class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :telegram_callback]
  layout false, only: [:new]
  
  def new
    redirect_to dashboard_path if current_user
    # For development: show login form
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
  
  def telegram_callback
    # Verify Telegram data
    auth_data = params.permit(:id, :first_name, :last_name, :username, :photo_url, :auth_date, :hash)
    
    if verify_telegram_auth(auth_data)
      # Find or create user
      user = User.find_or_create_by(telegram_id: auth_data[:id]) do |u|
        u.username = auth_data[:username]
        u.first_name = auth_data[:first_name]
        u.last_name = auth_data[:last_name]
        u.timezone = 'Europe/Madrid' # Default timezone
        u.language = 'ru'
      end
      
      # Update user info if changed
      user.update(
        username: auth_data[:username],
        first_name: auth_data[:first_name],
        last_name: auth_data[:last_name]
      )
      
      # Create session
      session[:user_id] = user.id
      
      redirect_to dashboard_path, notice: 'Успешно вошли в систему!'
    else
      redirect_to root_path, alert: 'Ошибка аутентификации'
    end
  end
  
  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: 'Вы вышли из системы'
  end
  
  private
  
  def verify_telegram_auth(auth_data)
    # Skip verification in development mode
    return true if Rails.env.development? && auth_data[:hash] == 'dev_mode_hash'

    bot_token = Rails.application.credentials.dig(:telegram, :bot_token)
    return false unless bot_token

    check_hash = auth_data[:hash]
    return false if check_hash.blank?

    # Create data check string - only include non-empty fields (as Telegram does)
    data_check_string = auth_data
      .to_h
      .except('hash', :hash)
      .reject { |_k, v| v.blank? }  # Filter out empty values
      .sort
      .map { |k, v| "#{k}=#{v}" }
      .join("\n")

    # Calculate hash using SHA256(bot_token) as secret key
    secret_key = Digest::SHA256.digest(bot_token)
    calculated_hash = OpenSSL::HMAC.hexdigest(
      'SHA256',
      secret_key,
      data_check_string
    )

    Rails.logger.info "Telegram auth check: calculated=#{calculated_hash[0..10]}... received=#{check_hash[0..10]}..."

    # Verify hash and check auth date (within 1 day)
    calculated_hash == check_hash &&
      auth_data[:auth_date].present? &&
      Time.at(auth_data[:auth_date].to_i) > 1.day.ago
  end
end
class GoogleAuthController < ApplicationController
  
  # Redirect to Google OAuth authorization
  def authorize
    oauth_service = Google::OauthService.new(current_user)
    state = generate_oauth_state
    
    # Store state in session for verification
    session[:oauth_state] = state
    session[:oauth_user_id] = current_user.id
    
    authorization_url = oauth_service.authorization_url(state)
    
    if request.xhr?
      render json: { authorization_url: authorization_url }
    else
      redirect_to authorization_url, allow_other_host: true
    end
  rescue GoogleOAuthError => e
    handle_oauth_error(e, "Failed to initiate Google authorization")
  end

  # Handle OAuth callback from Google
  def callback
    # Verify state parameter
    unless params[:state] == session[:oauth_state]
      return handle_oauth_error(nil, "Invalid OAuth state parameter")
    end
    
    # Check for authorization errors
    if params[:error]
      error_message = case params[:error]
                     when 'access_denied'
                       'Google Calendar authorization was denied'
                     else
                       "Google authorization error: #{params[:error]}"
                     end
      return handle_oauth_error(nil, error_message)
    end
    
    # Exchange code for tokens
    unless params[:code]
      return handle_oauth_error(nil, "No authorization code received from Google")
    end
    
    begin
      oauth_service = Google::OauthService.new(current_user)
      token_data = oauth_service.exchange_code_for_token(params[:code])
      
      # Get user info from Google
      user_info = oauth_service.get_user_info(token_data[:access_token])
      
      # Save tokens and user info
      oauth_service.save_tokens_for_user!(current_user, token_data)
      
      if user_info
        current_user.update!(
          settings: current_user.settings.merge({
            google_email: user_info['email'],
            google_name: user_info['name'],
            google_picture: user_info['picture']
          })
        )
      end
      
      # Clear session data
      session.delete(:oauth_state)
      session.delete(:oauth_user_id)
      
      # Start initial calendar sync
      Google::SyncCalendarJob.perform_later(current_user.id)
      
      Rails.logger.info "Google Calendar connected for user #{current_user.id}"
      
      # Redirect based on request source
      if session[:oauth_redirect_path]
        redirect_path = session.delete(:oauth_redirect_path)
        redirect_to redirect_path, notice: 'Google Calendar успешно подключен!'
      else
        redirect_to dashboard_path, notice: 'Google Calendar успешно подключен! Синхронизация началась.'
      end
      
    rescue GoogleOAuthError => e
      handle_oauth_error(e, "Failed to complete Google authorization")
    end
  end

  # Disconnect Google Calendar
  def disconnect
    oauth_service = Google::OauthService.new(current_user)
    
    if oauth_service.revoke_access
      # Clear user settings
      current_user.settings = current_user.settings.except('google_email', 'google_name', 'google_picture')
      current_user.save!
      
      # Mark existing calendar events as unsynced
      current_user.calendar_events.where.not(google_event_id: nil).update_all(google_event_id: nil)
      
      Rails.logger.info "Google Calendar disconnected for user #{current_user.id}"
      
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: 'Google Calendar отключен' }
        format.json { render json: { message: 'Google Calendar disconnected successfully' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to dashboard_path, alert: 'Ошибка отключения Google Calendar' }
        format.json { render json: { error: 'Failed to disconnect Google Calendar' }, status: :unprocessable_entity }
      end
    end
  end

  # Check connection status
  def status
    connected = Google::OauthService.connected?(current_user)
    
    status_data = {
      connected: connected,
      google_email: current_user.settings['google_email'],
      google_name: current_user.settings['google_name'],
      token_expires_at: current_user.google_token_expires_at
    }
    
    if connected && current_user.google_token_expires_at
      status_data[:expires_in_hours] = (((current_user.google_token_expires_at - Time.current) / 1.hour).round(1))
    end
    
    render json: status_data
  end

  # Manual calendar sync trigger
  def sync
    unless Google::OauthService.connected?(current_user)
      return render json: { error: 'Google Calendar not connected' }, status: :unprocessable_entity
    end
    
    # Queue sync job
    Google::SyncCalendarJob.perform_later(current_user.id)
    
    render json: { 
      message: 'Calendar sync started',
      status: 'queued'
    }
  end

  private

  def generate_oauth_state
    # Generate secure random state for OAuth
    SecureRandom.hex(32)
  end

  def handle_oauth_error(exception, message)
    Rails.logger.error "Google OAuth Error: #{message}"
    Rails.logger.error exception.message if exception
    Rails.logger.error exception.backtrace.join("\n") if exception
    
    # Clear session data
    session.delete(:oauth_state)
    session.delete(:oauth_user_id)
    
    respond_to do |format|
      format.html do
        redirect_to dashboard_path, alert: message
      end
      format.json do
        render json: { 
          error: message,
          details: exception&.message
        }, status: :unprocessable_entity
      end
    end
  end
end
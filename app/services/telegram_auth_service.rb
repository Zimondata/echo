class TelegramAuthService
  def self.initiate_auth(ip:, user_agent:, initiated_from: 'web')
    session = TelegramAuthSession.create!(
      initiated_from: initiated_from,
      client_ip: ip,
      user_agent: user_agent
    )

    {
      session_token: session.session_token,
      deep_link: generate_deep_link(session.session_token),
      qr_data: generate_qr_data(session.session_token),
      expires_at: session.expires_at
    }
  end

  def self.confirm_auth(session_token:, telegram_user:)
    Rails.logger.info "Confirming Telegram auth for telegram_user: #{telegram_user.id}"

    owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"].to_s
    unless owner_id.present? && ActiveSupport::SecurityUtils.secure_compare(owner_id, telegram_user.id.to_s)
      Rails.logger.warn "Telegram auth rejected: non-owner user"
      return { success: false, error: "Owner access only" }
    end
    
    session = TelegramAuthSession.active.find_by(session_token: session_token)
    unless session
      Rails.logger.warn "Auth confirmation failed: session not found or expired"
      return { success: false, error: 'Session not found or expired' }
    end

    Rails.logger.info "Auth session found: #{session.id}, status: #{session.status}"

    begin
      # Find or create user from Telegram data
      user = User.find_or_create_by(telegram_id: telegram_user.id) do |u|
        u.username = telegram_user.username
        u.first_name = telegram_user.first_name
        u.last_name = telegram_user.last_name
        u.language = telegram_user.language_code || 'ru'
        u.timezone = 'UTC'
        Rails.logger.info "Creating new user with telegram_id: #{telegram_user.id}"
      end

      handoff_session = nil
      TelegramAuthSession.transaction do
        # Update user info if changed
        user.update!(
          username: telegram_user.username,
          first_name: telegram_user.first_name,
          last_name: telegram_user.last_name
        )

        session.confirm!(user)
        handoff_session = TelegramAuthSession.create!(
          user: user,
          telegram_id: user.telegram_id,
          status: "confirmed",
          confirmed_at: Time.current,
          expires_at: 5.minutes.from_now,
          initiated_from: "telegram_handoff"
        )
      end
      
      Rails.logger.info "Auth confirmation successful for user: #{user.id}"
      { success: true, user: user, session: session, handoff_session: handoff_session }
      
    rescue StandardError => e
      Rails.logger.error "Auth confirmation failed with error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: "Ошибка создания пользователя: #{e.message}" }
    end
  end

  def self.generate_deep_link(session_token)
    bot_username = Telegram::BotService.bot_username
    "https://t.me/#{bot_username}?start=auth_#{session_token}"
  end

  def self.generate_qr_data(session_token)
    # Returns deep link for QR encoding
    generate_deep_link(session_token)
  end

  def self.browser_handoff_url(session_token, app_url:)
    base_url = app_url.to_s.delete_suffix("/")
    encoded_token = ERB::Util.url_encode(session_token.to_s)

    "#{base_url}/login#telegram_auth=#{encoded_token}"
  end
end

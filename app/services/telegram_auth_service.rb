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
    session = TelegramAuthSession.active.find_by(session_token: session_token)
    return { success: false, error: 'Session not found or expired' } unless session

    # Find or create user from Telegram data
    user = User.find_or_create_by(telegram_id: telegram_user.id) do |u|
      u.username = telegram_user.username
      u.first_name = telegram_user.first_name
      u.last_name = telegram_user.last_name
      u.language = telegram_user.language_code || 'ru'
      u.timezone = 'UTC'
    end

    # Update user info if changed
    user.update(
      username: telegram_user.username,
      first_name: telegram_user.first_name,
      last_name: telegram_user.last_name
    )

    session.confirm!(user)

    { success: true, user: user, session: session }
  end

  def self.generate_deep_link(session_token)
    bot_username = Rails.application.credentials.dig(:telegram, Rails.env.to_sym, :bot_name) ||
                   Rails.application.credentials.dig(:telegram, :bot_name)
    "https://t.me/#{bot_username}?start=auth_#{session_token}"
  end

  def self.generate_qr_data(session_token)
    # Returns deep link for QR encoding
    generate_deep_link(session_token)
  end
end

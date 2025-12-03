class TelegramAuthChannel < ApplicationCable::Channel
  def subscribed
    session_token = params[:session_token]

    # Validate session exists and is active
    @auth_session = TelegramAuthSession.active.find_by(session_token: session_token)

    if @auth_session
      stream_for @auth_session
      transmit({ type: 'connected', message: 'Ожидание подтверждения в Telegram...' })
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end
end

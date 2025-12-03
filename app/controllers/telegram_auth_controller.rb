class TelegramAuthController < ApplicationController
  skip_before_action :authenticate_user!

  # POST /telegram_auth/initiate
  def initiate
    result = TelegramAuthService.initiate_auth(
      ip: request.remote_ip,
      user_agent: request.user_agent
    )

    render json: result, status: :created
  end

  # GET /telegram_auth/:token/status
  def status
    session = TelegramAuthSession.find_by(session_token: params[:token])

    if session&.expired?
      session.expire!
      render json: { status: 'expired' }, status: :gone
    elsif session&.status == 'confirmed'
      render json: {
        status: 'confirmed',
        user_id: session.user_id,
        redirect_url: dashboard_path
      }
    elsif session
      render json: { status: 'pending' }
    else
      render json: { status: 'not_found' }, status: :not_found
    end
  end
end

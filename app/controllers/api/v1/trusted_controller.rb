class Api::V1::TrustedController < Api::BaseController
  private

  # Trusted machine endpoints authenticate exclusively with a scoped service
  # token. Browser sessions are deliberately ignored so two principals can
  # never be mixed in one request.
  def authenticate_user
    raw_token = request.authorization.to_s.match(/\ABearer\s+(.+)\z/i)&.captures&.first
    @service_token = EchoServiceToken.authenticate(raw_token, scope: "echo:trusted")
    @current_user = @service_token&.user

    return if @current_user

    render json: { error: "Scoped service token required" }, status: :unauthorized
  end
end

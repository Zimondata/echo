class Api::V1::EvidenceVerificationsController < Api::BaseController
  def update
    receipt = EvidenceReceipt.joins(:agent_run)
      .where(agent_runs: { user_id: current_user.id })
      .find(params[:id])
    if receipt.creator_service_token_id.blank? || receipt.creator_service_token_id == @service_token.id
      return error_response("Evidence requires a distinct recorded verifier", status: :conflict)
    end

    receipt.with_lock do
      receipt.update!(
        verified: true,
        metadata: (receipt.metadata || {}).merge(
          "verified_at" => Time.current.iso8601,
          "verifier_token_id" => @service_token.id,
          "verifier" => @service_token.name
        )
      )
    end

    success_response({ id: receipt.id, verified: receipt.verified }, message: "Evidence verified")
  end

  private

  def authenticate_user
    raw_token = request.authorization.to_s.match(/\ABearer\s+(.+)\z/i)&.captures&.first
    @service_token = EchoServiceToken.authenticate(raw_token, scope: "evidence:verify")
    @current_user = @service_token&.user
    return if @current_user

    render json: { error: "Verifier token required" }, status: :unauthorized
  end
end

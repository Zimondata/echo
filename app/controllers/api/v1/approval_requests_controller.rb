class Api::V1::ApprovalRequestsController < Api::V1::TrustedController
  before_action :find_approval
  rescue_from ApprovalRequest::AlreadyResolvedError,
              ApprovalRequest::ExpiredError,
              ApprovalRequest::PayloadChangedError,
              with: :handle_unresolvable_approval

  def resolve
    case params.require(:decision)
    when "approve"
      @approval.approve!(decided_by: "user", note: params[:decision_note])
    when "reject"
      @approval.reject!(decided_by: "user", note: params[:decision_note])
    else
      return error_response("Decision must be approve or reject", status: :unprocessable_entity)
    end

    success_response(serialize_approval(@approval.reload), message: "Approval resolved")
  end

  private

  def handle_unresolvable_approval(exception)
    error_response(exception.message, status: :conflict)
  end

  def find_approval
    @approval = ApprovalRequest.joins(agent_run: :user)
      .where(agent_runs: { user_id: current_user.id })
      .find(params[:id])
  end

  def serialize_approval(approval)
    {
      id: approval.id,
      agent_run_id: approval.agent_run_id,
      status: approval.status,
      risk_reason: approval.risk_reason,
      requested_at: approval.requested_at,
      expires_at: approval.expires_at,
      resolved_at: approval.resolved_at,
      decided_by: approval.decided_by,
      decision_note: approval.decision_note
    }
  end
end

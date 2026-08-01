class InboxController < ApplicationController
  rescue_from ApprovalRequest::AlreadyResolvedError,
              ApprovalRequest::ExpiredError,
              ApprovalRequest::PayloadChangedError,
              with: :render_conflict

  def index
    @captures = current_user.captures
      .includes(:intent_proposals)
      .where(status: %w[received transcribing parsed needs_review ready])
      .order(occurred_at: :desc)

    @active_runs = current_user.agent_runs
      .includes(:intent_proposal, :evidence_receipts)
      .where(status: %w[queued running waiting_approval])
      .order(created_at: :desc)

    @pending_approvals = ApprovalRequest.joins(:agent_run)
      .includes(:agent_run)
      .where(agent_runs: { user_id: current_user.id }, status: "pending")
      .order(requested_at: :desc)
  end

  def review_proposal
    proposal = IntentProposal.joins(:capture)
      .where(captures: { user_id: current_user.id })
      .find(params[:id])
    return render json: { error: "Only proposed intents can be reviewed" }, status: :conflict unless proposal.status == "proposed"

    IntentProposal.transaction do
      case params.require(:decision)
      when "accept"
        proposal.accept!
      when "reject"
        proposal.reject!(note: params[:review_note])
      else
        return render json: { error: "Decision must be accept or reject" }, status: :unprocessable_entity
      end
      refresh_capture_status!(proposal.capture)
    end

    render json: { status: proposal.status }
  end

  def resolve_approval
    approval = ApprovalRequest.joins(:agent_run)
      .where(agent_runs: { user_id: current_user.id })
      .find(params[:id])

    case params.require(:decision)
    when "approve"
      approval.approve!(decided_by: "user:#{current_user.id}", note: params[:decision_note])
    when "reject"
      approval.reject!(decided_by: "user:#{current_user.id}", note: params[:decision_note])
    else
      return render json: { error: "Decision must be approve or reject" }, status: :unprocessable_entity
    end

    render json: { status: approval.reload.status }
  end

  private

  def refresh_capture_status!(capture)
    statuses = capture.intent_proposals.reload.pluck(:status)
    status = if statuses.include?("proposed")
      "needs_review"
    elsif statuses.include?("accepted")
      "ready"
    else
      "done"
    end
    capture.update!(status: status)
  end

  def render_conflict(exception)
    render json: { error: exception.message }, status: :conflict
  end
end

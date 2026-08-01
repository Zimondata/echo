class AgentsController < ApplicationController
  def index
    ApprovalRequest.expire_stale_for!(current_user)

    @active_runs = current_user.agent_runs
      .includes(:intent_proposal, :evidence_receipts, :approval_requests)
      .where(status: %w[queued running waiting_approval])
      .order(updated_at: :desc)

    @finished_runs = current_user.agent_runs
      .includes(:intent_proposal, :evidence_receipts)
      .where(status: %w[succeeded failed cancelled])
      .order(updated_at: :desc)
      .limit(30)

    @pending_approvals = ApprovalRequest.joins(:agent_run)
      .where(agent_runs: { user_id: current_user.id }, status: "pending")
      .order(requested_at: :desc)
  end
end

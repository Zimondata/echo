class Api::V1::AgentRunsController < Api::V1::TrustedController
  before_action :find_run, only: [:show, :transition]
  rescue_from AgentRun::InvalidTransitionError, AgentRun::MissingEvidenceError, with: :handle_invalid_transition

  def index
    runs = current_user.agent_runs
      .includes(:intent_proposal, :approval_requests, :evidence_receipts)
      .order(created_at: :desc)
    runs = runs.where(status: params[:status]) if params[:status].present?

    paginated = paginate(runs)
    paginated[:data] = paginated[:data].map { |run| serialize_run(run) }
    success_response(paginated)
  end

  def show
    success_response(serialize_run(@run))
  end

  def create
    proposal = IntentProposal.joins(:capture)
      .where(captures: { user_id: current_user.id })
      .find(agent_run_params[:intent_proposal_id])

    unless proposal.status == 'accepted' && proposal.owner_type == 'gary'
      return error_response('Only accepted Gary proposals can become AgentRuns', status: :unprocessable_entity)
    end

    run = AgentRun.transaction do
      requires_approval = %w[confirm clarify].include?(proposal.risk_level)
      record = current_user.agent_runs.create!(
        agent_run_params.merge(
          intent_proposal: proposal,
          approval_required: requires_approval,
          status: requires_approval ? 'waiting_approval' : 'queued'
        )
      )

      if requires_approval
        record.approval_requests.create!(
          risk_reason: approval_reason_for(proposal),
          requested_at: Time.current
        )
      end
      record
    end

    success_response(serialize_run(run), message: 'AgentRun created', status: :created)
  end

  def transition
    case params.require(:action_name)
    when 'start'
      @run.start!
    when 'succeed'
      @run.transaction do
        @run.succeed!
        @run.intent_proposal.update!(status: 'applied')
        @run.intent_proposal.capture.update!(status: 'done')
      end
    when 'fail'
      @run.fail!(params[:error_message].presence || 'AgentRun failed')
    when 'cancel'
      @run.cancel!
    else
      return error_response('Unknown transition', status: :unprocessable_entity)
    end

    success_response(serialize_run(@run.reload), message: 'AgentRun updated')
  end

  private

  def handle_invalid_transition(exception)
    error_response(exception.message, status: :unprocessable_entity)
  end

  def find_run
    @run = current_user.agent_runs
      .includes(:intent_proposal, :approval_requests, :evidence_receipts)
      .find(params[:id])
  end

  def agent_run_params
    params.require(:agent_run).permit(:intent_proposal_id, :objective, :definition_of_done, :executor)
  end

  def approval_reason_for(proposal)
    proposal.payload['risk_reason'].presence || "Action requires #{proposal.risk_level} approval"
  end

  def serialize_run(run)
    {
      id: run.id,
      intent_proposal_id: run.intent_proposal_id,
      objective: run.objective,
      definition_of_done: run.definition_of_done,
      executor: run.executor,
      status: run.status,
      approval_required: run.approval_required,
      started_at: run.started_at,
      finished_at: run.finished_at,
      error_message: run.error_message,
      approvals: run.approval_requests.map do |approval|
        {
          id: approval.id,
          status: approval.status,
          risk_reason: approval.risk_reason,
          requested_at: approval.requested_at,
          resolved_at: approval.resolved_at
        }
      end,
      evidence_receipts: run.evidence_receipts.map do |receipt|
        {
          id: receipt.id,
          receipt_type: receipt.receipt_type,
          summary: receipt.summary,
          target_ref: receipt.target_ref,
          result_ref: receipt.result_ref,
          verification: receipt.verification,
          verified: receipt.verified,
          occurred_at: receipt.occurred_at
        }
      end
    }
  end
end

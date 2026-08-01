class Api::V1::IntentProposalsController < Api::V1::TrustedController
  before_action :find_proposal

  def review
    unless @proposal.status == "proposed"
      return error_response("Only proposed intents can be reviewed or changed", status: :conflict)
    end

    IntentProposal.transaction do
      @proposal.update!(proposal_params) if params[:proposal].present?

      case params.require(:decision)
      when 'accept'
        @proposal.accept!
      when 'reject'
        @proposal.reject!(note: params.dig(:proposal, :review_note))
      else
        return error_response('Decision must be accept or reject', status: :unprocessable_entity)
      end

      refresh_capture_status!
    end

    success_response(serialize_proposal(@proposal), message: 'Proposal reviewed')
  end

  private

  def find_proposal
    @proposal = IntentProposal.joins(:capture)
      .where(captures: { user_id: current_user.id })
      .find(params[:id])
  end

  def proposal_params
    params.require(:proposal).permit(
      :title,
      :description,
      :owner_type,
      :risk_level,
      :due_at,
      :review_note,
      source_span: {},
      payload: {},
      entities: {}
    )
  end

  def refresh_capture_status!
    capture = @proposal.capture
    statuses = capture.intent_proposals.reload.pluck(:status)

    capture.update!(
      status: if statuses.include?('proposed')
        'needs_review'
      elsif statuses.include?('accepted')
        'ready'
      else
        'done'
      end
    )
  end

  def serialize_proposal(proposal)
    {
      id: proposal.id,
      capture_id: proposal.capture_id,
      intent_type: proposal.intent_type,
      title: proposal.title,
      description: proposal.description,
      owner_type: proposal.owner_type,
      risk_level: proposal.risk_level,
      confidence: proposal.confidence&.to_f,
      source_span: proposal.source_span,
      payload: proposal.payload,
      entities: proposal.entities,
      status: proposal.status,
      due_at: proposal.due_at,
      accepted_at: proposal.accepted_at,
      rejected_at: proposal.rejected_at,
      review_note: proposal.review_note
    }
  end
end

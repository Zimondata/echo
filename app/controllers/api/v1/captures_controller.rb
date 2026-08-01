class Api::V1::CapturesController < Api::V1::TrustedController
  before_action :find_capture, only: :show

  def index
    captures = current_user.captures.includes(:intent_proposals).order(occurred_at: :desc)
    captures = captures.where(status: params[:status]) if params[:status].present?

    paginated = paginate(captures)
    paginated[:data] = paginated[:data].map { |capture| serialize_capture(capture) }
    success_response(paginated)
  end

  def show
    success_response(serialize_capture(@capture))
  end

  def create
    attributes = capture_params.to_h.deep_symbolize_keys
    proposals = attributes.delete(:intent_proposals) || []

    existing = current_user.captures.includes(:intent_proposals).find_by(
      idempotency_key: attributes[:idempotency_key]
    )
    return success_response(serialize_capture(existing).merge(deduplicated: true)) if existing

    capture = Capture.transaction do
      record = current_user.captures.create!(attributes)
      proposals.each { |proposal| record.intent_proposals.create!(proposal) }
      record.update!(status: proposals.any? ? 'needs_review' : 'ready')
      record
    end

    success_response(
      serialize_capture(capture).merge(deduplicated: false),
      message: 'Capture created',
      status: :created
    )
  end

  private

  def find_capture
    @capture = current_user.captures.includes(:intent_proposals).find(params[:id])
  end

  def capture_params
    params.require(:capture).permit(
      :source_type,
      :source_ref,
      :idempotency_key,
      :raw_text,
      :transcript,
      :audio_retention_policy,
      :parser_version,
      :occurred_at,
      transcript_versions: [],
      segment_timestamps: [],
      attachments: [],
      provider_ledger: [],
      metadata: {},
      intent_proposals: [
        :intent_type,
        :title,
        :description,
        :owner_type,
        :risk_level,
        :confidence,
        :due_at,
        source_span: {},
        payload: {},
        entities: {}
      ]
    )
  end

  def serialize_capture(capture)
    {
      id: capture.id,
      source_type: capture.source_type,
      source_ref: capture.source_ref,
      status: capture.status,
      transcript: capture.transcript,
      attachments: capture.attachments,
      provider_ledger: capture.provider_ledger,
      occurred_at: capture.occurred_at,
      created_at: capture.created_at,
      intent_proposals: capture.intent_proposals.map { |proposal| serialize_proposal(proposal) }
    }
  end

  def serialize_proposal(proposal)
    {
      id: proposal.id,
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
      rejected_at: proposal.rejected_at
    }
  end
end

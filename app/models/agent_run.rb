class AgentRun < ApplicationRecord
  class MissingEvidenceError < StandardError; end
  class InvalidTransitionError < StandardError; end

  STATUSES = %w[queued running waiting_approval succeeded failed cancelled].freeze
  APPROVAL_BOUND_FIELDS = %w[user_id intent_proposal_id executor objective definition_of_done].freeze

  belongs_to :user
  belongs_to :intent_proposal
  has_many :evidence_receipts, dependent: :destroy
  has_many :approval_requests, dependent: :destroy

  validates :objective, :definition_of_done, presence: true
  validates :executor, presence: true
  validates :status, inclusion: { in: STATUSES }
  before_update :protect_approval_bound_fields

  def start!
    require_status!("queued")
    update!(status: "running", started_at: Time.current, finished_at: nil, error_message: nil)
  end

  def succeed!
    require_status!("running")
    unless evidence_receipts.verified.exists?
      raise MissingEvidenceError, "A verified evidence receipt is required before success"
    end

    update!(status: "succeeded", finished_at: Time.current, error_message: nil)
  end

  def fail!(message)
    require_status!("queued", "running")
    update!(status: "failed", finished_at: Time.current, error_message: message)
  end

  def cancel!
    require_status!("queued", "running", "waiting_approval")
    update!(status: "cancelled", finished_at: Time.current)
  end

  private

  def protect_approval_bound_fields
    return if (changes_to_save.keys & APPROVAL_BOUND_FIELDS).empty?
    return unless approval_requests.where(status: %w[pending approved]).exists?

    raise ActiveRecord::ReadOnlyRecord,
      "Agent run action fields are immutable while an approval is pending or approved"
  end

  def require_status!(*allowed)
    return if allowed.include?(status)

    raise InvalidTransitionError, "Cannot transition AgentRun from #{status}"
  end
end

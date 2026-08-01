class IntentProposal < ApplicationRecord
  INTENT_TYPES = %w[
    task reminder calendar_event message research agent_action journal_entry
    idea decision project_update person_fact note attachment_context discard
  ].freeze
  OWNER_TYPES = %w[user gary external system].freeze
  RISK_LEVELS = %w[auto reversible confirm clarify].freeze
  STATUSES = %w[proposed accepted rejected applied failed].freeze
  APPROVAL_BOUND_FIELDS = %w[
    capture_id intent_type title description owner_type risk_level due_at
    source_span payload entities
  ].freeze

  belongs_to :capture
  has_many :agent_runs, dependent: :restrict_with_error

  validates :intent_type, inclusion: { in: INTENT_TYPES }
  validates :owner_type, inclusion: { in: OWNER_TYPES }
  validates :risk_level, inclusion: { in: RISK_LEVELS }
  validates :status, inclusion: { in: STATUSES }
  validates :title, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validate :source_span_is_ordered
  before_update :protect_approval_bound_fields

  def accept!
    update!(status: "accepted", accepted_at: Time.current, rejected_at: nil)
  end

  def reject!(note: nil)
    update!(status: "rejected", rejected_at: Time.current, accepted_at: nil, review_note: note)
  end

  private

  def protect_approval_bound_fields
    return if (changes_to_save.keys & APPROVAL_BOUND_FIELDS).empty?
    return unless agent_runs.joins(:approval_requests)
      .where(approval_requests: { status: %w[pending approved] })
      .exists?

    raise ActiveRecord::ReadOnlyRecord,
      "Intent action fields are immutable while an approval is pending or approved"
  end

  def source_span_is_ordered
    start_position = source_span["start"] || source_span["start_ms"]
    end_position = source_span["end"] || source_span["end_ms"]
    return if start_position.present? && end_position.present? && start_position.to_i <= end_position.to_i

    errors.add(:source_span, "must point to an ordered source range")
  end
end

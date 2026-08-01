class Capture < ApplicationRecord
  IMMUTABLE_FIELDS = %w[
    user_id source_type source_ref idempotency_key raw_text transcript
    transcript_versions segment_timestamps attachments occurred_at
  ].freeze

  belongs_to :user
  has_many :intent_proposals, dependent: :destroy

  validates :source_type, :source_ref, :idempotency_key, :occurred_at, presence: true
  validates :idempotency_key, uniqueness: { scope: :user_id }
  validates :source_ref, uniqueness: { scope: [:user_id, :source_type] }
  validates :status, inclusion: {
    in: %w[received transcribing parsed needs_review ready queued running done failed cancelled snoozed]
  }

  before_update :protect_source_fields

  private

  def protect_source_fields
    return if (changes_to_save.keys & IMMUTABLE_FIELDS).empty?

    raise ActiveRecord::ReadOnlyRecord, 'Capture source fields are immutable'
  end
end

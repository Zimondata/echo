class EvidenceReceipt < ApplicationRecord
  belongs_to :agent_run
  belongs_to :creator_service_token, class_name: "EchoServiceToken", optional: true

  validates :receipt_type, :summary, :verification, :occurred_at, presence: true

  scope :verified, -> { where(verified: true) }
end

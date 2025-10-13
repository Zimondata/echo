class Reminder < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :entry, optional: true

  # Validations
  validates :reminder_type, presence: true, inclusion: { in: %w[one_time recurring smart] }
  validates :remind_at, presence: true
  validates :status, inclusion: { in: %w[pending sent snoozed cancelled] }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :due, -> { pending.where("remind_at <= ?", Time.current) }
  scope :upcoming, -> { pending.where("remind_at > ?", Time.current).order(:remind_at) }

  # Methods
  def due?
    status == "pending" && remind_at <= Time.current
  end

  def mark_as_sent!
    update!(status: "sent", sent_at: Time.current)
  end

  def snooze!(duration_minutes = 30)
    update!(
      status: "pending",
      remind_at: Time.current + duration_minutes.minutes,
      metadata: metadata.merge(snoozed_count: (metadata["snoozed_count"] || 0) + 1)
    )
  end

  def cancel!
    update!(status: "cancelled")
  end
end

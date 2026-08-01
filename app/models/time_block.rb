class TimeBlock < ApplicationRecord
  SOURCES = %w[manual].freeze
  PREVIOUS_TASK_STATUSES = Task::UNSCHEDULED_STATUSES.freeze

  belongs_to :task

  scope :active, -> { where(cancelled_at: nil) }

  validates :starts_at, :ends_at, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :previous_task_status, inclusion: { in: PREVIOUS_TASK_STATUSES }
  validate :ends_after_start

  def duration_minutes
    return unless starts_at && ends_at

    ((ends_at - starts_at) / 60).to_i
  end

  private

  def ends_after_start
    return unless starts_at && ends_at
    return if ends_at > starts_at

    errors.add(:ends_at, "должно быть позже начала")
  end
end

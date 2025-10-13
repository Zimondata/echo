class CalendarEvent < ApplicationRecord
  # Associations
  belongs_to :entry, optional: true
  belongs_to :user

  # Validations
  validates :title, presence: true
  validates :start_time, presence: true
  validates :event_type, inclusion: { in: %w[plan note reminder] }

  # Scopes
  scope :upcoming, -> { where("start_time >= ?", Time.current).order(:start_time) }
  scope :past, -> { where("start_time < ?", Time.current).order(start_time: :desc) }
  scope :plans, -> { where(event_type: "plan") }
  scope :notes, -> { where(event_type: "note") }

  # Methods
  def synced_with_google?
    google_event_id.present?
  end

  def duration_minutes
    return nil unless end_time
    ((end_time - start_time) / 60).to_i
  end
end

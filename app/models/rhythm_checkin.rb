class RhythmCheckin < ApplicationRecord
  STATES = %w[full minimum skipped returned].freeze

  belongs_to :rhythm

  validates :local_date, presence: true, uniqueness: { scope: :rhythm_id }
  validates :state, inclusion: { in: STATES }
  validates :previous_state, inclusion: { in: STATES }, allow_nil: true

  scope :recent, -> { order(local_date: :desc) }

  def return!
    raise ActiveRecord::RecordInvalid, self unless state == "skipped"

    update!(state: "returned", previous_state: "skipped", returned_at: Time.current)
  end
end

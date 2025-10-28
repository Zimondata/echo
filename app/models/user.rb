class User < ApplicationRecord
  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :language, presence: true

  # Associations
  has_many :entries, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :insights, dependent: :destroy
  has_many :nutrition_entries, dependent: :destroy
  has_many :activity_entries, dependent: :destroy
  has_many :quests, dependent: :destroy

  # Scopes
  scope :active, -> { where.not(telegram_id: nil) }

  # Methods
  def full_name
    [first_name, last_name].compact.join(" ").presence || username || "User"
  end

  # Entry context tracking for corrections
  def update_last_entry_context(entry_ids)
    update!(
      last_entry_ids: entry_ids,
      last_entry_timestamp: Time.current
    )
  end

  def get_recent_entries_for_correction(within_minutes: 10)
    return [] unless last_entry_ids.present? && last_entry_timestamp.present?

    # Check if the entries were created recently enough
    time_diff = Time.current - last_entry_timestamp
    return [] if time_diff > within_minutes.minutes

    # Return the recent entries
    entries.where(id: last_entry_ids).order(:created_at)
  end

  def can_correct_recent_entries?
    return false unless last_entry_ids.present? && last_entry_timestamp.present?

    time_diff = Time.current - last_entry_timestamp
    time_diff <= 10.minutes # 10 minute window for corrections
  end
end

class User < ApplicationRecord
  # Validations
  validates :telegram_id, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :language, presence: true

  # Associations
  has_many :entries, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :reminders, dependent: :destroy

  # Scopes
  scope :with_google_connected, -> { where.not(google_refresh_token: nil) }

  # Methods
  def full_name
    [first_name, last_name].compact.join(" ").presence || username || "User"
  end

  def google_connected?
    google_refresh_token.present?
  end

  def google_token_valid?
    google_token_expires_at.present? && google_token_expires_at > Time.current
  end
end

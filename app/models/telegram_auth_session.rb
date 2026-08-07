class TelegramAuthSession < ApplicationRecord
  belongs_to :user, optional: true

  validates :session_token, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[pending confirmed expired] }
  validates :expires_at, presence: true

  scope :active, -> { where(status: 'pending').where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current).where(status: 'pending') }
  scope :confirmed, -> { where(status: 'confirmed') }

  before_validation :set_defaults, on: :create

  def self.consume_confirmed(session_token)
    owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"].to_s
    return if owner_id.blank?

    now = Time.current
    scope = where(
      session_token: session_token,
      status: "confirmed",
      telegram_id: owner_id
    ).where.not(user_id: nil).where("expires_at > ?", now)

    return unless scope.update_all(status: "expired", updated_at: now) == 1

    find_by(session_token: session_token)
  end

  def expired?
    expires_at <= Time.current
  end

  def confirm!(user)
    update!(
      user: user,
      telegram_id: user.telegram_id,
      status: 'confirmed',
      confirmed_at: Time.current
    )
  end

  def expire!
    update!(status: 'expired')
  end

  private

  def set_defaults
    self.session_token ||= SecureRandom.urlsafe_base64(24)
    self.expires_at ||= 30.minutes.from_now  # Увеличили с 15 до 30 минут
    self.status ||= 'pending'
  end
end

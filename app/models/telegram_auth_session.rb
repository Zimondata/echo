class TelegramAuthSession < ApplicationRecord
  belongs_to :user, optional: true

  validates :session_token, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[pending confirmed expired] }
  validates :expires_at, presence: true

  scope :active, -> { where(status: 'pending').where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current).where(status: 'pending') }
  scope :confirmed, -> { where(status: 'confirmed') }

  before_validation :set_defaults, on: :create

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

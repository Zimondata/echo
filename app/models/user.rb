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

  # Methods
  def full_name
    [first_name, last_name].compact.join(" ").presence || username || "User"
  end
end

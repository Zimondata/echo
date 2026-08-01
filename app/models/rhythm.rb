class Rhythm < ApplicationRecord
  MAX_ACTIVE_PER_USER = 3

  belongs_to :user
  has_many :rhythm_checkins, dependent: :destroy

  validates :name, :full_version, :minimum_version, presence: true
  validates :name, length: { maximum: 120 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :active_limit, if: :active?

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :created_at) }

  private

  def active_limit
    relation = user.rhythms.active
    relation = relation.where.not(id: id) if persisted?
    return if relation.count < MAX_ACTIVE_PER_USER

    errors.add(:base, "Можно иметь не больше трёх активных ритмов")
  end
end

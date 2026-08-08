class Project < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :nullify

  validates :name, presence: true, length: { maximum: 255 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_name

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position, :name, :id) }

  def active?
    archived_at.nil?
  end

  def archived?
    !active?
  end

  def archive!(expected_lock_version)
    with_lock do
      raise ActiveRecord::StaleObjectError.new(self, "archive") unless lock_version == expected_lock_version

      update!(archived_at: Time.current) if active?
    end
  end

  private

  def normalize_name
    self.name = name.strip if name.is_a?(String)
  end
end

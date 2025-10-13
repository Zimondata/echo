class Entry < ApplicationRecord
  # Associations
  belongs_to :user
  has_one :calendar_event, dependent: :destroy
  has_many :reminders, dependent: :destroy

  # pgvector neighbor
  has_neighbors :embedding

  # Validations
  validates :entry_type, presence: true, inclusion: { in: %w[diary idea plan plan_update] }
  validates :content, presence: true
  validates :status, presence: true, inclusion: { in: %w[active archived deleted] }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :diaries, -> { where(entry_type: "diary") }
  scope :ideas, -> { where(entry_type: "idea") }
  scope :plans, -> { where(entry_type: "plan") }
  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_priority, -> { order(priority: :desc) }

  # Callbacks
  before_validation :set_occurred_at, on: :create

  # Methods
  def diary?
    entry_type == "diary"
  end

  def idea?
    entry_type == "idea"
  end

  def plan?
    entry_type == "plan"
  end

  def plan_update?
    entry_type == "plan_update"
  end

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end

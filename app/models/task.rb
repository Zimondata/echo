class Task < ApplicationRecord
  OWNER_TYPES = %w[user assistant collaborator system].freeze
  STATUSES = %w[inbox next scheduled waiting someday completed dropped].freeze
  # Statuses that still wait for a slot on the calendar.
  UNSCHEDULED_STATUSES = %w[inbox next].freeze
  DEFAULT_OWNER_TYPE = "user".freeze
  DEFAULT_STATUS = "inbox".freeze

  # Associations
  belongs_to :user
  belongs_to :project, optional: true
  has_many :time_blocks, dependent: :destroy
  has_many :task_steps, -> { ordered }, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :owner_type, inclusion: { in: OWNER_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :estimate_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :drop_reason, length: { maximum: 500 }, allow_nil: true
  validate :optionals_must_be_castable
  validate :project_must_share_owner
  validate :new_project_assignment_must_be_active

  # Callbacks
  before_validation :normalize_text_fields

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :unscheduled, -> { active.where(status: UNSCHEDULED_STATUSES) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  private

  def normalize_text_fields
    self.title = title.strip if title.is_a?(String)
    self.description = description.strip.presence if description.is_a?(String)
    self.next_action = next_action.strip.presence if next_action.is_a?(String)
    self.drop_reason = drop_reason.strip.presence if drop_reason.is_a?(String)
  end

  def optionals_must_be_castable
    if estimate_minutes.nil? && estimate_minutes_before_type_cast.present?
      errors.add(:estimate_minutes, :not_a_number)
    end

    errors.add(:due_on, :invalid) if due_on.nil? && due_on_before_type_cast.present?
  end

  def project_must_share_owner
    errors.add(:project, "должен принадлежать владельцу задачи") if project && project.user_id != user_id
  end

  def new_project_assignment_must_be_active
    return unless project&.archived? && will_save_change_to_project_id?

    errors.add(:project, "уже находится в архиве")
  end
end

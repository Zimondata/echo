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
  validates :category, presence: true, inclusion: { in: %w[inbox work life health ideas projects] }
  validates :dashboard_status, presence: true, inclusion: { in: %w[new triaged processed archived] }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :diaries, -> { where(entry_type: "diary") }
  scope :ideas, -> { where(entry_type: "idea") }
  scope :plans, -> { where(entry_type: "plan") }
  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_priority, -> { order(priority: :desc) }
  
  # Dashboard scopes
  scope :inbox, -> { where(category: "inbox") }
  scope :by_category, ->(category) { where(category: category) }
  scope :new_items, -> { where(dashboard_status: "new") }
  scope :triaged, -> { where(dashboard_status: "triaged") }
  scope :processed, -> { where(dashboard_status: "processed") }
  scope :needs_attention, -> { where(dashboard_status: ["new", "triaged"]) }
  scope :with_tags, -> { where.not(tags: [nil, ""]) }

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

  # Dashboard status helpers
  def new?
    dashboard_status == "new"
  end

  def triaged?
    dashboard_status == "triaged"
  end

  def processed?
    dashboard_status == "processed"
  end

  def needs_attention?
    ["new", "triaged"].include?(dashboard_status)
  end

  # Tag management
  def tag_list
    tags&.split(',')&.map(&:strip) || []
  end

  def tag_list=(new_tags)
    self.tags = Array(new_tags).map(&:strip).reject(&:blank?).join(', ')
  end

  def add_tag(tag)
    current_tags = tag_list
    current_tags << tag.strip unless current_tags.include?(tag.strip)
    self.tag_list = current_tags
  end

  def remove_tag(tag)
    current_tags = tag_list
    current_tags.delete(tag.strip)
    self.tag_list = current_tags
  end

  # Category helpers
  def inbox?
    category == "inbox"
  end

  def categorized?
    category != "inbox"
  end

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end

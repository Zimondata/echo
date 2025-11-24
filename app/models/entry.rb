class Entry < ApplicationRecord
  # Associations
  belongs_to :user
  has_one :calendar_event, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_one :nutrition_entry, dependent: :destroy
  has_many :quests, dependent: :destroy
  
  # Self-referential associations for grouped entries
  belongs_to :parent_entry, class_name: 'Entry', optional: true
  has_many :child_entries, class_name: 'Entry', foreign_key: 'parent_entry_id', dependent: :destroy

  # Validations
  validates :entry_type, presence: true, inclusion: { in: %w[diary idea plan plan_update nutrition] }
  validates :content, presence: true
  validates :status, presence: true, inclusion: { in: %w[active archived deleted] }
  validates :category, presence: true, inclusion: { in: %w[inbox work life health ideas projects] }
  validates :dashboard_status, presence: true, inclusion: { in: %w[new triaged processed archived] }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :diaries, -> { where(entry_type: "diary") }
  scope :ideas, -> { where(entry_type: "idea") }
  scope :plans, -> { where(entry_type: "plan") }
  scope :nutrition, -> { where(entry_type: "nutrition") }
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
  scope :parent_entries, -> { where(parent_entry_id: nil) }
  scope :grouped_by, ->(group_id) { where(group_id: group_id) }

  # Callbacks
  before_validation :set_occurred_at, on: :create

  # Methods
  def content_length
    content.to_s.split.size
  end
  
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

  def nutrition?
    entry_type == "nutrition"
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

  # Grouping methods
  def is_parent?
    parent_entry_id.nil? && child_entries.any?
  end

  def is_child?
    parent_entry_id.present?
  end

  def is_standalone?
    parent_entry_id.nil? && child_entries.empty?
  end

  def main_entry
    parent_entry || self
  end

  def grouped_entries
    if group_id.present?
      Entry.grouped_by(group_id)
    else
      [self]
    end
  end

  def all_related_content
    if is_parent?
      [content] + child_entries.pluck(:content)
    elsif is_child?
      [parent_entry.content] + parent_entry.child_entries.pluck(:content)
    else
      [content]
    end
  end

  # Idea management methods
  def idea_category_display
    return nil unless idea?
    
    {
      'business' => '💼 Бизнес',
      'tech' => '⚙️ Технологии', 
      'content' => '📝 Контент',
      'personal' => '🎯 Личное',
      'creative' => '🎨 Креатив'
    }[idea_category] || idea_category&.humanize
  end

  def idea_status_display
    return nil unless idea?
    
    {
      'new' => '📥 Новая',
      'research' => '🔍 Исследование',
      'quest' => '🎯 Квест',
      'in_progress' => '🚀 В работе',
      'done' => '✅ Готово',
      'archive' => '🗄️ Архив'
    }[idea_status] || idea_status&.humanize
  end

  def idea_priority_display
    return nil unless idea?
    
    case idea_priority
    when 9..10 then '🔥 Горячая'
    when 7..8 then '⭐ Актуальная'
    when 4..6 then '💡 Перспективная'
    when 1..3 then '🗄️ Архивная'
    else '💡 Обычная'
    end
  end

  def can_generate_quest?
    idea? && !quest_generated && ['new', 'research'].include?(idea_status)
  end

  def has_research?
    research_data.present? && research_data.any?
  end

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end

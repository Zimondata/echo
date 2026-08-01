class Reminder < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :entry, optional: true

  # Validations
  validates :reminder_type, presence: true, inclusion: { in: %w[one_time recurring smart] }
  validates :remind_at, presence: true
  validates :status, inclusion: { in: %w[pending sending sent snoozed cancelled] }
  validates :priority, inclusion: { in: %w[high medium low] }, allow_nil: true
  validates :smart_type, inclusion: { in: %w[idea pattern goal context suggestion] }, allow_nil: true

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :due, -> { pending.where("remind_at <= ?", Time.current) }
  scope :upcoming, -> { pending.where("remind_at > ?", Time.current).order(:remind_at) }
  scope :smart, -> { where(reminder_type: "smart") }
  scope :regular, -> { where(reminder_type: %w[one_time recurring]) }
  scope :high_priority, -> { where(priority: "high") }
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END")) }

  # Smart reminder type scopes
  scope :idea_reminders, -> { smart.where(smart_type: "idea") }
  scope :pattern_reminders, -> { smart.where(smart_type: "pattern") }
  scope :goal_reminders, -> { smart.where(smart_type: "goal") }
  scope :context_reminders, -> { smart.where(smart_type: "context") }
  scope :suggestion_reminders, -> { smart.where(smart_type: "suggestion") }

  # Methods
  def due?
    status == "pending" && remind_at <= Time.current
  end

  def smart_reminder?
    reminder_type == "smart"
  end

  def high_confidence?
    confidence_score && confidence_score >= 80
  end

  def related_entries
    return Entry.none if related_entry_ids.blank?
    user.entries.where(id: related_entry_ids)
  end

  def mark_as_sent!
    update!(status: "sent", sent_at: Time.current)
  end

  def snooze!(duration_minutes = 30)
    base_time = [ remind_at, Time.current ].compact.max
    update!(
      status: "pending",
      remind_at: base_time + duration_minutes.minutes,
      metadata: (metadata || {}).merge(snoozed_count: ((metadata || {})["snoozed_count"] || 0) + 1),
      user_feedback: "snoozed"
    )
  end

  def cancel!
    update!(status: "cancelled")
  end

  def mark_helpful!
    update!(user_feedback: "helpful")
  end

  def mark_not_helpful!
    update!(user_feedback: "not_helpful")
  end

  # Format message with emojis based on type
  def formatted_message
    emoji = case smart_type
    when "idea" then "💡"
    when "pattern" then "📊"
    when "goal" then "🎯"
    when "context" then "🧠"
    when "suggestion" then "✨"
    else "🔔"
    end

    "#{emoji} #{message}"
  end
end

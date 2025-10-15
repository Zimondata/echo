class Insight < ApplicationRecord
  belongs_to :user

  validates :insight_type, presence: true, inclusion: { in: %w[daily_summary weekly_digest trend_analysis mood_tracker productivity_insight goal_progress] }
  validates :title, presence: true

  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :by_type, ->(type) { where(insight_type: type) }
  scope :recent, -> { order(generated_at: :desc) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def daily_summary?
    insight_type == "daily_summary"
  end

  def weekly_digest?
    insight_type == "weekly_digest"
  end

  def trend_analysis?
    insight_type == "trend_analysis"
  end
end

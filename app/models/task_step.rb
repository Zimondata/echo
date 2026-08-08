class TaskStep < ApplicationRecord
  belongs_to :task

  validates :text, presence: true, length: { maximum: 500 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_text

  scope :ordered, -> { order(:position, :id) }

  def completed?
    completed_at.present?
  end

  private

  def normalize_text
    self.text = text.strip if text.is_a?(String)
  end
end

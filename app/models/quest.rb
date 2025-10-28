class Quest < ApplicationRecord
  belongs_to :entry
  belongs_to :user

  # Validations
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[active paused completed cancelled] }
  validates :priority, presence: true, numericality: { in: 1..10 }
  validates :completion_rate, numericality: { in: 0..100 }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  scope :due_soon, -> { where('due_date <= ?', 3.days.from_now) }
  scope :overdue, -> { where('due_date < ?', Time.current) }

  # Methods
  def status_display
    {
      'active' => '🎯 Активный',
      'paused' => '⏸️ Приостановлен', 
      'completed' => '✅ Завершен',
      'cancelled' => '❌ Отменен'
    }[status] || status.humanize
  end

  def priority_display
    case priority
    when 9..10 then '🔥 Критический'
    when 7..8 then '⭐ Высокий'
    when 4..6 then '📋 Средний'
    when 1..3 then '📝 Низкий'
    else '📋 Обычный'
    end
  end

  def progress_display
    "#{completion_rate}%"
  end

  def is_overdue?
    due_date.present? && due_date < Time.current && status == 'active'
  end

  def days_until_due
    return nil unless due_date.present?
    
    days = (due_date.to_date - Date.current).to_i
    return "Просрочен на #{-days} дн." if days < 0
    return "Сегодня" if days == 0
    return "Завтра" if days == 1
    "Через #{days} дн."
  end

  def steps_list
    steps || {}
  end

  def checklist
    steps_list['checklist'] || []
  end

  def completed_steps_count
    checklist.count { |step| step['completed'] == true }
  end

  def total_steps_count
    checklist.count
  end

  def completion_percentage
    return 0 if total_steps_count == 0
    ((completed_steps_count.to_f / total_steps_count) * 100).round
  end

  def update_completion_rate!
    rate = completion_percentage
    update!(completion_rate: rate)
    
    # Update progress in steps
    if steps.present?
      steps['progress'] = {
        'completed_tasks' => completed_steps_count,
        'total_tasks' => total_steps_count,
        'completion_percentage' => rate
      }
      save!
    end
    
    # Auto-complete quest if all steps are done
    if rate == 100 && status == 'active'
      update!(status: 'completed')
    end
    
    rate
  end

  def complete_step(step_id)
    return false unless checklist.present?
    
    step = checklist.find { |s| s['id'] == step_id.to_i }
    return false unless step
    
    step['completed'] = true
    step['completed_at'] = Time.current.iso8601
    
    update_completion_rate!
    true
  end

  def uncomplete_step(step_id)
    return false unless checklist.present?
    
    step = checklist.find { |s| s['id'] == step_id.to_i }
    return false unless step
    
    step['completed'] = false
    step['completed_at'] = nil
    
    update_completion_rate!
    true
  end

  def toggle_step(step_id)
    return false unless checklist.present?
    
    step = checklist.find { |s| s['id'] == step_id.to_i }
    return false unless step
    
    if step['completed']
      uncomplete_step(step_id)
    else
      complete_step(step_id)
    end
  end

  def high_priority_tasks
    checklist.select { |step| step['priority'] == 'high' }
  end

  def incomplete_tasks
    checklist.select { |step| !step['completed'] }
  end

  def completed_tasks
    checklist.select { |step| step['completed'] }
  end

  def next_task
    # Сначала высокоприоритетные, потом по порядку
    high_priority_incomplete = incomplete_tasks.select { |step| step['priority'] == 'high' }
    return high_priority_incomplete.first if high_priority_incomplete.any?
    
    incomplete_tasks.first
  end

  def goals_list
    steps_list['goals'] || []
  end

  def expected_outcomes
    steps_list['expected_outcomes'] || []
  end

  def estimated_duration
    steps_list['estimated_duration'] || 'Не указано'
  end

  # Scope for recent quests
  scope :recent, -> { order(created_at: :desc) }
end

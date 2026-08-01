class ReviewsController < ApplicationController
  def index
    zone = ActiveSupport::TimeZone[current_user.timezone] || Time.zone
    @today = Time.current.in_time_zone(zone).to_date
    @completed_tasks = current_user.tasks.active.where(status: "completed", completed_at: zone.local(@today.year, @today.month, @today.day).all_day)
    @unfinished_tasks = current_user.tasks.active.where(status: %w[inbox next scheduled waiting]).order(:due_on, :created_at)
    @overdue_tasks = @unfinished_tasks.where("due_on < ?", @today)
    @waiting_tasks = @unfinished_tasks.where(status: "waiting")
    @recent_evidence = EvidenceReceipt.joins(:agent_run)
      .where(agent_runs: { user_id: current_user.id }, verified: true)
      .order(occurred_at: :desc)
      .limit(8)
    @tomorrow_tasks = @unfinished_tasks.where(due_on: @today + 1.day).limit(5)
  end
end

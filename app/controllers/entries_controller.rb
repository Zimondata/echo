class EntriesController < ApplicationController
  before_action :set_entry, only: [:show]

  def index
    @entries = current_user.entries.order(created_at: :desc).limit(20)
  end

  def show
    # Entry is set by before_action
  end

  def diary
    @user = current_user
    @entries = current_user.entries.where(entry_type: "diary").order(created_at: :desc).limit(50)
    render :diary
  end

  def ideas
    @entries = current_user.entries.where(entry_type: "idea").parent_entries.order(created_at: :desc).limit(20)
    render :ideas
  end

  def plans
    @entries = current_user.entries.where(entry_type: "plan").order(created_at: :desc).limit(20)
    render :index
  end

  private

  def set_entry
    @entry = current_user.entries.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to entries_path, alert: 'Запись не найдена'
  end
end

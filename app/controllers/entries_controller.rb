class EntriesController < ApplicationController
  def index
    @user = User.first
    @entries = @user.entries.order(created_at: :desc).page(params[:page]).per(20)
  end

  def show
    @entry = Entry.find(params[:id])
  end

  def diary
    @user = User.first
    @entries = @user.entries.where(entry_type: "diary").order(created_at: :desc).page(params[:page]).per(20)
    render :index
  end

  def ideas
    @user = User.first
    @entries = @user.entries.where(entry_type: "idea").order(created_at: :desc).page(params[:page]).per(20)
    render :index
  end

  def plans
    @user = User.first
    @entries = @user.entries.where(entry_type: "plan").order(created_at: :desc).page(params[:page]).per(20)
    render :index
  end
end

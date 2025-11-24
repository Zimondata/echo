class LandingController < ApplicationController
  skip_before_action :authenticate_user!
  layout 'landing'
  
  def index
    redirect_to dashboard_path if logged_in?
    @variation = 'minimalist'
  end
  
  def brutalist
    redirect_to dashboard_path if logged_in?
    @variation = 'brutalist'
    render :index
  end
  
  def terminal
    redirect_to dashboard_path if logged_in?
    @variation = 'terminal'
    render :index
  end
  
  def retro
    redirect_to dashboard_path if logged_in?
    @variation = 'retro'
    render :index
  end
  
  def organic
    redirect_to dashboard_path if logged_in?
    @variation = 'organic'
    render :index
  end
end
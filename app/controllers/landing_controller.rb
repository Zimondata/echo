class LandingController < ApplicationController
  skip_before_action :authenticate_user!
  layout 'landing'

  def index
    redirect_to dashboard_path if logged_in?
  end

  def video
    render layout: 'landing_video', template: 'landing/index_video'
  end

  def showcase
    return redirect_to dashboard_path if logged_in?

    render layout: 'landing_showcase', template: 'landing/showcase'
  end
end
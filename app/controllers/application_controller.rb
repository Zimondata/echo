class ApplicationController < ActionController::Base
  LOCAL_DEVELOPMENT_HOSTS = %w[localhost 127.0.0.1 ::1].freeze

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :authenticate_user!
  helper_method :current_user, :logged_in?
  
  private
  
  def current_user
    return @current_user if defined?(@current_user)

    candidate = if session[:user_id]
      User.find_by(id: session[:user_id])
    else
      local_development_user
    end

    unless owner_user?(candidate)
      session.delete(:user_id)
      candidate = nil
    end

    @current_user = candidate
  end

  def owner_user?(user)
    owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"].to_s

    owner_id.present? && user&.telegram_id.present? &&
      ActiveSupport::SecurityUtils.secure_compare(owner_id, user.telegram_id.to_s)
  end

  def local_development_user
    return unless local_development_access?

    User.active.find_by(id: ENV["ECHO_LOCAL_USER_ID"])
  end

  def local_development_access?
    Rails.env.development? &&
      ENV["ECHO_LOCAL_AUTH_BYPASS"] == "1" &&
      ENV["ECHO_LOCAL_USER_ID"].present? &&
      request.local? &&
      LOCAL_DEVELOPMENT_HOSTS.include?(request.host)
  end
  
  def logged_in?
    !!current_user
  end
  
  def authenticate_user!
    unless logged_in?
      redirect_to root_path, alert: 'Необходимо войти в систему'
    end
  end
end

class Api::BaseController < ActionController::API
  include ActionController::MimeResponds

  # API controllers don't have CSRF protection by default
  before_action :authenticate_user
  before_action :set_current_user

  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_unprocessable_entity

  private

  def authenticate_user
    # For API authentication, we'll use session-based auth like the main app
    # In production this could be JWT or OAuth
    user_id = session[:user_id] || params[:user_id] # Allow user_id in params for API testing
    @current_user = User.find_by(id: user_id) if user_id
    
    unless @current_user
      render json: { error: 'Authentication required' }, status: :unauthorized
    end
  end

  def set_current_user
    # Temporarily skip Current.user since it's not configured yet
    # Current.user = @current_user
  end

  def current_user
    @current_user
  end

  def handle_standard_error(exception)
    Rails.logger.error "API Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render json: { 
      error: 'Internal server error',
      message: Rails.env.development? ? exception.message : nil
    }, status: :internal_server_error
  end

  def handle_not_found(exception)
    render json: { error: 'Resource not found' }, status: :not_found
  end

  def handle_unprocessable_entity(exception)
    render json: { 
      error: 'Validation failed',
      messages: exception.record&.errors&.full_messages || []
    }, status: :unprocessable_entity
  end

  def paginate(collection, per_page: 20)
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || per_page, 100].min

    {
      data: collection.offset((page - 1) * per_page).limit(per_page),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: collection.count,
        total_pages: (collection.count.to_f / per_page).ceil
      }
    }
  end

  def success_response(data, message: nil, status: :ok)
    response = { data: data }
    response[:message] = message if message.present?
    render json: response, status: status
  end

  def error_response(message, status: :bad_request, details: nil)
    response = { error: message }
    response[:details] = details if details.present?
    render json: response, status: status
  end
end
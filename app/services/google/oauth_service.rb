class Google::OauthService
  include ActiveSupport::Benchmarkable

  SCOPES = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/userinfo.profile'
  ].freeze

  def initialize(user = nil)
    @user = user
    @config = {
      client_id: Rails.application.credentials.dig(:google, :client_id),
      client_secret: Rails.application.credentials.dig(:google, :client_secret),
      redirect_uri: Rails.application.credentials.dig(:google, :redirect_uri) || 'http://localhost:3000/auth/google/callback'
    }
  end

  # Generate authorization URL for OAuth flow
  def authorization_url(state = nil)
    client = build_oauth_client
    
    client.authorization_uri(
      scope: SCOPES.join(' '),
      state: state,
      access_type: 'offline',
      prompt: 'consent',
      include_granted_scopes: true
    ).to_s
  end

  # Exchange authorization code for access token
  def exchange_code_for_token(authorization_code)
    client = build_oauth_client
    
    benchmark "Google OAuth token exchange" do
      token_response = client.fetch_access_token!(
        code: authorization_code
      )
      
      # Extract tokens and expiration
      {
        access_token: token_response['access_token'],
        refresh_token: token_response['refresh_token'],
        expires_at: Time.current + token_response['expires_in'].seconds,
        token_type: token_response['token_type'] || 'Bearer'
      }
    end
  rescue StandardError => e
    Rails.logger.error "Google OAuth token exchange failed: #{e.message}"
    raise GoogleOAuthError, "Failed to exchange authorization code: #{e.message}"
  end

  # Refresh access token using refresh token
  def refresh_access_token(refresh_token)
    return nil unless refresh_token

    client = build_oauth_client
    client.refresh_token = refresh_token

    benchmark "Google OAuth token refresh" do
      token_response = client.fetch_access_token!
      
      {
        access_token: token_response['access_token'],
        expires_at: Time.current + token_response['expires_in'].seconds,
        refresh_token: token_response['refresh_token'] || refresh_token # Keep old if not provided
      }
    end
  rescue StandardError => e
    Rails.logger.error "Google OAuth token refresh failed: #{e.message}"
    raise GoogleOAuthError, "Failed to refresh access token: #{e.message}"
  end

  # Get user info from Google
  def get_user_info(access_token)
    require 'net/http'
    require 'json'
    
    uri = URI('https://www.googleapis.com/oauth2/v2/userinfo')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to get Google user info: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Google user info request failed: #{e.message}"
    nil
  end

  # Check if user has valid Google tokens
  def self.connected?(user)
    user.google_connected? && user.google_token_valid?
  end

  # Revoke Google access for user
  def revoke_access
    return false unless @user&.google_access_token

    begin
      uri = URI('https://oauth2.googleapis.com/revoke')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = "token=#{@user.google_access_token}"
      
      response = http.request(request)
      
      if response.code == '200'
        @user.update!(
          google_access_token: nil,
          google_refresh_token: nil,
          google_token_expires_at: nil
        )
        true
      else
        Rails.logger.error "Failed to revoke Google access: #{response.code}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "Google access revocation failed: #{e.message}"
      false
    end
  end

  # Update user with OAuth tokens
  def save_tokens_for_user!(user, token_data)
    user.update!(
      google_access_token: token_data[:access_token],
      google_refresh_token: token_data[:refresh_token] || user.google_refresh_token,
      google_token_expires_at: token_data[:expires_at]
    )
    
    Rails.logger.info "Google OAuth tokens saved for user #{user.id}"
  end

  # Get valid access token for user (refresh if needed)
  def get_valid_access_token(user = nil)
    target_user = user || @user
    return nil unless target_user

    # Return current token if still valid
    if target_user.google_token_valid?
      return target_user.google_access_token
    end

    # Try to refresh token
    if target_user.google_refresh_token
      begin
        token_data = refresh_access_token(target_user.google_refresh_token)
        save_tokens_for_user!(target_user, token_data)
        return token_data[:access_token]
      rescue GoogleOAuthError
        # Refresh failed, user needs to re-authorize
        Rails.logger.warn "Google token refresh failed for user #{target_user.id}, re-authorization required"
        return nil
      end
    end

    nil
  end

  private

  def build_oauth_client
    client = Signet::OAuth2::Client.new(
      client_id: @config[:client_id],
      client_secret: @config[:client_secret],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      redirect_uri: @config[:redirect_uri]
    )
    
    if @user&.google_access_token
      client.access_token = @user.google_access_token
      client.refresh_token = @user.google_refresh_token
    end
    
    client
  rescue StandardError => e
    Rails.logger.error "Failed to build OAuth client: #{e.message}"
    raise GoogleOAuthError, "OAuth client configuration error: #{e.message}"
  end

  def logger
    Rails.logger
  end
end

# Custom error class
class GoogleOAuthError < StandardError; end
# Google OAuth Configuration for Calendar API
# Commented out - Google Calendar integration not yet configured
# require 'google/apis/calendar_v3'
# require 'googleauth'

# Google Calendar API Client Configuration
Rails.application.config.google_calendar = {
  # OAuth 2.0 credentials
  client_id: ENV['GOOGLE_CLIENT_ID'] || Rails.application.credentials.dig(:google, :client_id),
  client_secret: ENV['GOOGLE_CLIENT_SECRET'] || Rails.application.credentials.dig(:google, :client_secret),
  redirect_uri: ENV['GOOGLE_REDIRECT_URI'] || Rails.application.credentials.dig(:google, :redirect_uri) || "#{Rails.application.config.force_ssl ? 'https' : 'http'}://#{Rails.application.config.hosts.first || 'localhost:3000'}/auth/google/callback",
  
  # OAuth scopes for Calendar API
  scope: [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/userinfo.profile'
  ],
  
  # API settings
  application_name: 'Echo AI Assistant',
  application_version: '1.0.0'
}

# Validate configuration in development
if Rails.env.development?
  config = Rails.application.config.google_calendar
  
  unless config[:client_id] && config[:client_secret]
    Rails.logger.warn <<~WARNING
      ⚠️  Google Calendar integration not configured!
      
      To enable Google Calendar sync, add the following to config/credentials.yml.enc:
      
      google:
        client_id: YOUR_GOOGLE_CLIENT_ID
        client_secret: YOUR_GOOGLE_CLIENT_SECRET
        redirect_uri: http://localhost:3000/auth/google/callback
      
      Get credentials from: https://console.cloud.google.com/apis/credentials
      Enable: Google Calendar API
    WARNING
  end
end
# OpenAI configuration
# The ruby-openai gem should be loaded by Bundler automatically
if defined?(OpenAI)
  begin
    OpenAI.configure do |config|
      config.access_token = Rails.application.credentials.dig(:openai, :api_key)
      config.log_errors = Rails.env.development?
    end
  rescue => e
    Rails.logger.error "OpenAI configuration failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
  end
else
  Rails.logger.warn "OpenAI gem is not loaded. AI features will not be available."
end

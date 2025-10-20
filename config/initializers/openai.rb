begin
  require 'openai'

  OpenAI.configure do |config|
    config.access_token = ENV["OPENAI_API_KEY"]
    config.log_errors = Rails.env.development?
  end
rescue LoadError => e
  Rails.logger.warn "OpenAI gem not available: #{e.message}"
rescue => e
  Rails.logger.error "OpenAI configuration failed: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
end

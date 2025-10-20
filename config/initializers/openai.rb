begin
  require 'faraday'
  require 'openai'

  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_API_KEY", nil)
    config.log_errors = Rails.env.development?
  end
rescue LoadError => e
  Rails.logger.warn "OpenAI gem not loaded: #{e.message}"
rescue NameError => e
  Rails.logger.warn "OpenAI initialization error: #{e.message}"
end

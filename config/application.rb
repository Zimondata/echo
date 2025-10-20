require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Explicitly require OpenAI gem to ensure it loads before services
# If OpenAI gem is not available, create stub to prevent load errors
begin
  require 'openai'
rescue LoadError => e
  warn "OpenAI gem not available, creating stub: #{e.message}"

  # Create stub OpenAI module to prevent errors during class loading
  module OpenAI
    class Client
      def initialize(*); end
      def chat(*); raise "OpenAI gem not available"; end
      def audio(*); raise "OpenAI gem not available"; end
      def embeddings(*); raise "OpenAI gem not available"; end
    end

    def self.configure
      yield self if block_given?
    end

    def self.access_token=(*); end
    def self.log_errors=(*); end
  end
end

module Echo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

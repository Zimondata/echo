ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Faraday 2.x compatibility patch - must be before any gem loads
require 'faraday'
unless defined?(Faraday::Error)
  module Faraday
    class Error < StandardError; end
  end
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.

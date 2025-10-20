# Faraday 2.x compatibility patch for gems expecting Faraday::Error
#
# Faraday 2.x removed the base Faraday::Error class and changed error hierarchy.
# Some gems (like older versions of ruby-openai) still reference it.
# This patch adds backward compatibility.

if defined?(Faraday) && !defined?(Faraday::Error)
  module Faraday
    # Base error class for backward compatibility
    class Error < StandardError; end
  end
end

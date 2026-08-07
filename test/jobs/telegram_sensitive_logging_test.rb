require "test_helper"

class TelegramSensitiveLoggingTest < ActiveSupport::TestCase
  test "telegram job arguments are not logged" do
    assert_equal false, TelegramWebhookJob.log_arguments
  end

  test "telegram payloads are filtered from parameter logs" do
    capability = "telegram_auth_confirm_super-secret-capability"
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(
      message: { text: "/start #{capability}" },
      callback_query: { data: capability },
      telegram: { message: { text: capability } }
    )

    assert_equal "[FILTERED]", filtered[:message]
    assert_equal "[FILTERED]", filtered[:callback_query]
    assert_equal "[FILTERED]", filtered[:telegram]
    refute_includes filtered.inspect, capability
  end
end

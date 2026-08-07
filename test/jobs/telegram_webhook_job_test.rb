require "test_helper"

class TelegramWebhookJobTest < ActiveJob::TestCase
  setup do
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = "424242"
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "drops a non-owner update before creating a user or calling handlers" do
    update = {
      "update_id" => 1,
      "message" => {
        "message_id" => 2,
        "from" => { "id" => 999999, "is_bot" => false, "first_name" => "Other" },
        "chat" => { "id" => 999999, "type" => "private" },
        "date" => Time.current.to_i,
        "text" => "/start"
      }
    }

    assert_no_difference "User.count" do
      TelegramWebhookJob.perform_now(update)
    end
  end
end

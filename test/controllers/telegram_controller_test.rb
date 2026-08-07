require "test_helper"

class TelegramControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_webhook_secret = ENV["TELEGRAM_WEBHOOK_SECRET"]
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["TELEGRAM_WEBHOOK_SECRET"] = "test-webhook-secret"
    ENV["ECHO_OWNER_TELEGRAM_ID"] = "424242"
  end

  teardown do
    ENV["TELEGRAM_WEBHOOK_SECRET"] = @previous_webhook_secret
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "rejects a webhook without the Telegram secret" do
    assert_no_enqueued_jobs do
      post "/telegram/webhook", params: owner_message_update, as: :json
    end

    assert_response :unauthorized
  end

  test "rejects a webhook with the wrong Telegram secret" do
    assert_no_enqueued_jobs do
      post "/telegram/webhook",
        params: owner_message_update,
        headers: webhook_headers("wrong"),
        as: :json
    end

    assert_response :unauthorized
  end

  test "rejects an authentic webhook from a non-owner" do
    assert_no_enqueued_jobs do
      post "/telegram/webhook",
        params: owner_message_update(from_id: 999999),
        headers: webhook_headers,
        as: :json
    end

    assert_response :forbidden
  end

  test "enqueues an authentic owner update" do
    assert_enqueued_with(job: TelegramWebhookJob) do
      post "/telegram/webhook",
        params: owner_message_update,
        headers: webhook_headers,
        as: :json
    end

    assert_response :ok
  end

  private

  def webhook_headers(secret = "test-webhook-secret")
    { "X-Telegram-Bot-Api-Secret-Token" => secret }
  end

  def owner_message_update(from_id: 424242)
    {
      update_id: 1,
      message: {
        message_id: 2,
        from: { id: from_id, is_bot: false, first_name: "Owner" },
        chat: { id: from_id, type: "private" },
        date: Time.current.to_i,
        text: "/start"
      }
    }
  end
end

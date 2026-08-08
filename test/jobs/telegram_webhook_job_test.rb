require "test_helper"
require "minitest/mock"

class TelegramWebhookJobTest < ActiveJob::TestCase
  setup do
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = "424242"
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "confirmed auth button hands the one-time session to the browser" do
    user = users(:john)
    ENV["ECHO_OWNER_TELEGRAM_ID"] = user.telegram_id.to_s
    auth_session = TelegramAuthSession.create!
    sent_messages = []
    api = Object.new
    api.define_singleton_method(:edit_message_text) { |**| true }
    api.define_singleton_method(:send_message) { |**payload| sent_messages << payload; true }
    api.define_singleton_method(:answer_callback_query) { |**| true }
    client = Struct.new(:api).new(api)
    update = {
      "update_id" => 10,
      "callback_query" => {
        "id" => "callback-1",
        "from" => {
          "id" => user.telegram_id,
          "is_bot" => false,
          "first_name" => user.first_name,
          "username" => user.username,
          "language_code" => "ru"
        },
        "message" => {
          "message_id" => 20,
          "date" => Time.current.to_i,
          "chat" => { "id" => user.telegram_id, "type" => "private" },
          "text" => "Подтвердить вход"
        },
        "chat_instance" => "instance-1",
        "data" => "telegram_auth_confirm_#{auth_session.session_token}"
      }
    }

    Telegram::BotService.stub(:client, client) do
      TelegramAuthChannel.stub(:broadcast_to, ->(*) { true }) do
        TelegramWebhookJob.perform_now(update)
      end
    end

    button_url = sent_messages.last.fetch(:reply_markup).inline_keyboard[0][0].url
    handoff_token = URI(button_url).fragment.to_s.delete_prefix("telegram_auth=")
    assert_equal "https://echo.datapine.space/login", button_url.split("#", 2).first
    refute_equal auth_session.session_token, handoff_token
    refute_includes button_url, "?session_token="

    handoff_session = TelegramAuthSession.find_by!(session_token: handoff_token)
    assert_equal user, handoff_session.user
    assert_equal "confirmed", handoff_session.status
    assert_equal "telegram_handoff", handoff_session.initiated_from
    assert_equal "confirmed", auth_session.reload.status
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

  test "drops an owner auth callback from a group before minting a browser handoff" do
    user = users(:john)
    ENV["ECHO_OWNER_TELEGRAM_ID"] = user.telegram_id.to_s
    auth_session = TelegramAuthSession.create!
    update = {
      "update_id" => 11,
      "callback_query" => {
        "id" => "callback-group",
        "from" => {
          "id" => user.telegram_id,
          "is_bot" => false,
          "first_name" => user.first_name,
          "username" => user.username
        },
        "message" => {
          "message_id" => 21,
          "date" => Time.current.to_i,
          "chat" => { "id" => -100_123_456, "type" => "group" },
          "text" => "Подтвердить вход"
        },
        "chat_instance" => "instance-group",
        "data" => "telegram_auth_confirm_#{auth_session.session_token}"
      }
    }

    assert_no_difference "TelegramAuthSession.count" do
      TelegramWebhookJob.perform_now(update)
    end

    assert_equal "pending", auth_session.reload.status
  end
end

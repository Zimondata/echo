require "test_helper"
require "minitest/mock"
require "stringio"

class TelegramBotServiceTest < ActiveSupport::TestCase
  setup do
    @previous_token = ENV["TELEGRAM_BOT_TOKEN"]
    @previous_username = ENV["TELEGRAM_BOT_USERNAME"]
    ENV["TELEGRAM_BOT_TOKEN"] = "test-token"
    ENV["TELEGRAM_BOT_USERNAME"] = "echo_owner_bot"
  end

  teardown do
    ENV["TELEGRAM_BOT_TOKEN"] = @previous_token
    ENV["TELEGRAM_BOT_USERNAME"] = @previous_username
  end

  test "uses the dedicated Echo bot configuration from the environment" do
    assert_equal "test-token", Telegram::BotService.bot_token
    assert_equal "echo_owner_bot", Telegram::BotService.bot_username
  end

  test "does not log keyboard callback capabilities" do
    secret_capability = "telegram_auth_confirm_super-secret-capability"
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    api = Object.new
    api.define_singleton_method(:send_message) { |**| true }
    client = Struct.new(:api).new(api)

    Telegram::BotService.stub(:client, client) do
      Telegram::BotService.send_message_with_keyboard(
        chat_id: 1,
        text: "Confirm",
        keyboard: [[{ text: "Confirm", callback_data: secret_capability }]]
      )
    end

    refute_includes output.string, secret_capability
  ensure
    Rails.logger = original_logger
  end
end

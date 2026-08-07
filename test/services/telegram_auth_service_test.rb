require "test_helper"
require "ostruct"

class TelegramAuthServiceTest < ActiveSupport::TestCase
  setup do
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = users(:john).telegram_id.to_s
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "rejects authentication for anyone except the configured owner" do
    auth_session = TelegramAuthSession.create!
    stranger = OpenStruct.new(
      id: 999_999_999,
      username: "stranger",
      first_name: "Stranger",
      last_name: "User",
      language_code: "en"
    )

    result = TelegramAuthService.confirm_auth(
      session_token: auth_session.session_token,
      telegram_user: stranger
    )

    assert_equal false, result[:success]
    assert_equal "Owner access only", result[:error]
    assert_equal "pending", auth_session.reload.status
    assert_not User.exists?(telegram_id: stranger.id)
  end
end

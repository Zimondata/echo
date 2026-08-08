require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @user.telegram_id.to_s
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "confirmed Telegram auth is POST-only and one-time" do
    auth_session = TelegramAuthSession.create!(
      user: @user,
      telegram_id: @user.telegram_id,
      status: "confirmed",
      confirmed_at: Time.current,
      expires_at: 5.minutes.from_now
    )

    get complete_telegram_auth_sessions_path, params: { session_token: auth_session.session_token }
    assert_response :not_found

    post complete_telegram_auth_sessions_path, params: { session_token: auth_session.session_token }
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert_equal "expired", auth_session.reload.status

    reset!
    post complete_telegram_auth_sessions_path, params: { session_token: auth_session.session_token }
    assert_response :unauthorized
  end

  test "expired confirmed Telegram auth cannot log in" do
    auth_session = TelegramAuthSession.create!(
      user: @user,
      telegram_id: @user.telegram_id,
      status: "confirmed",
      confirmed_at: 10.minutes.ago,
      expires_at: 1.minute.ago
    )

    post complete_telegram_auth_sessions_path, params: { session_token: auth_session.session_token }

    assert_response :unauthorized
    assert_equal "confirmed", auth_session.reload.status
  end

  test "confirmed Telegram auth for a non-owner cannot log in" do
    other_user = users(:moscow_user)
    auth_session = TelegramAuthSession.create!(
      user: other_user,
      telegram_id: other_user.telegram_id,
      status: "confirmed",
      confirmed_at: Time.current,
      expires_at: 5.minutes.from_now
    )

    post complete_telegram_auth_sessions_path, params: { session_token: auth_session.session_token }

    assert_response :unauthorized
    assert_equal "confirmed", auth_session.reload.status
  end

  test "login page completes auth through one POST function without token URLs" do
    get "/login"

    assert_response :ok
    assert_includes response.body, "window.completeTelegramAuth"
    assert_includes response.body, "method: 'POST'"
    refute_includes response.body, "/telegram_auth/${sessionToken}/status"
    refute_includes response.body, "/sessions/complete_telegram_auth?session_token="
  end

  test "login page consumes a Telegram browser handoff from the URL fragment" do
    get "/login"

    assert_response :ok
    assert_includes response.body, "window.location.hash"
    assert_includes response.body, "fragmentParams.get('telegram_auth')"
    assert_includes response.body, "history.replaceState"
    assert_includes response.body, "window.__echoTelegramAuthPromise"
    assert_includes response.body, "Ссылка для входа истекла или уже использована"

    clear_index = response.body.index("history.replaceState")
    first_external_script_index = response.body.index("cdn.tailwindcss.com")
    assert_operator clear_index, :<, first_external_script_index
  end
end

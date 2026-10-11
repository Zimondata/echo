require "test_helper"

class PlanFirstNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
  end

  test "Telegram completion sends the owner to the weekly Plan" do
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)

    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }

    assert_response :success
    assert_equal calendar_events_path(view: "week"), response.parsed_body.fetch("redirect_url")
  end

  test "confirmed Telegram status advertises the weekly Plan" do
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)

    post "/telegram_auth/status", params: { session_token: auth_session.session_token }, as: :json

    assert_response :success
    assert_equal calendar_events_path(view: "week"), response.parsed_body.fetch("redirect_url")
  end

  test "an already authenticated owner opening login goes to the weekly Plan" do
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }

    get login_path

    assert_redirected_to calendar_events_path(view: "week")
  end
end

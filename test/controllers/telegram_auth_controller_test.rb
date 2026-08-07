require "test_helper"

class TelegramAuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auth_session = TelegramAuthSession.create!
  end

  test "status accepts the capability only in a POST body" do
    post "/telegram_auth/status", params: { session_token: @auth_session.session_token }, as: :json

    assert_response :ok
    assert_equal "pending", response.parsed_body.fetch("status")
  end

  test "legacy token-in-URL status route is absent" do
    get "/telegram_auth/#{@auth_session.session_token}/status"

    assert_response :not_found
  end
end

require "test_helper"

class ActivityEntriesControllerTest < ActionDispatch::IntegrationTest
  test "redirects guests to login" do
    get activity_entries_url
    assert_redirected_to root_path
  end

  test "renders authenticated activity index" do
    auth = TelegramAuthSession.create!
    auth.confirm!(users(:john))
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    assert_response :success

    get activity_entries_url
    assert_response :success
  end
end

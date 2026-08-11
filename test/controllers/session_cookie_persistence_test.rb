require "test_helper"

class SessionCookiePersistenceTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:john)
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @owner.telegram_id.to_s
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "successful Telegram auth issues a bounded persistent browser session cookie" do
    travel_to Time.zone.parse("2026-08-11 12:00:00") do
      post complete_telegram_auth_sessions_path,
           params: { session_token: confirmed_auth_session.session_token }

      cookie = response.headers.fetch("Set-Cookie")
      expires = cookie[/expires=([^;]+)/i, 1]

      assert expires, "expected the session cookie to include Expires"
      assert_in_delta 30.days, Time.httpdate(expires) - Time.current, 2.seconds
      assert_match(/path=\//i, cookie)
      assert_match(/httponly/i, cookie)
      assert_match(/samesite=lax/i, cookie)
      refute_match(/domain=/i, cookie)
    end
  end

  test "authenticated cookie survives a new browser session object" do
    cookie_pair = authenticate_and_capture_cookie
    reopened_browser = open_session

    reopened_browser.get calendar_events_path(view: "month"),
                         headers: { "Cookie" => cookie_pair }

    assert_equal 200, reopened_browser.response.status
  end

  test "active use renews the bounded cookie lifetime" do
    started_at = Time.zone.parse("2026-08-11 12:00:00")
    cookie_pair = nil

    travel_to started_at do
      cookie_pair = authenticate_and_capture_cookie
    end

    travel_to started_at + 10.days do
      active_browser = open_session
      active_browser.get calendar_events_path(view: "month"),
                         headers: { "Cookie" => cookie_pair }

      assert_equal 200, active_browser.response.status
      renewed_cookie = active_browser.response.headers.fetch("Set-Cookie")
      renewed_expires = renewed_cookie[/expires=([^;]+)/i, 1]
      assert renewed_expires, "expected active use to renew Expires"
      assert_in_delta 30.days, Time.httpdate(renewed_expires) - Time.current, 2.seconds
    end
  end

  test "authenticated cookie expires after the bounded lifetime" do
    started_at = Time.zone.parse("2026-08-11 12:00:00")
    cookie_pair = nil

    travel_to started_at do
      cookie_pair = authenticate_and_capture_cookie
    end

    travel_to started_at + 31.days do
      reopened_browser = open_session
      reopened_browser.get calendar_events_path(view: "month"),
                           headers: { "Cookie" => cookie_pair }

      assert_equal 302, reopened_browser.response.status
      assert_equal root_url, reopened_browser.response.location
    end
  end

  test "tampered persistent cookie fails closed" do
    cookie_pair = authenticate_and_capture_cookie
    name, value = cookie_pair.split("=", 2)
    replacement = value.end_with?("a") ? "b" : "a"
    tampered_cookie = "#{name}=#{value[0...-1]}#{replacement}"
    reopened_browser = open_session

    reopened_browser.get calendar_events_path(view: "month"),
                         headers: { "Cookie" => tampered_cookie }

    assert_equal 302, reopened_browser.response.status
    assert_equal root_url, reopened_browser.response.location
  end

  test "explicit logout removes authenticated browser access" do
    browser = open_session
    browser.post complete_telegram_auth_sessions_path,
                 params: { session_token: confirmed_auth_session.session_token }
    assert_equal 200, browser.response.status

    browser.delete logout_path
    assert_equal 302, browser.response.status

    browser.get calendar_events_path(view: "month")
    assert_equal 302, browser.response.status
    assert_equal root_url, browser.response.location
  end

  private

  def authenticate_and_capture_cookie
    browser = open_session
    browser.post complete_telegram_auth_sessions_path,
                 params: { session_token: confirmed_auth_session.session_token }
    assert_equal 200, browser.response.status

    browser.response.headers.fetch("Set-Cookie").split(";", 2).first
  end

  def confirmed_auth_session
    TelegramAuthSession.create!(
      user: @owner,
      telegram_id: @owner.telegram_id,
      status: "confirmed",
      confirmed_at: Time.current,
      expires_at: 5.minutes.from_now
    )
  end
end

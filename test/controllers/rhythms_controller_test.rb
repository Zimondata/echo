require "test_helper"

class RhythmsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    assert_response :success
  end

  test "owner can create edit and persist a rhythm through refresh" do
    assert_difference "@user.rhythms.count", 1 do
      post rhythms_path, params: { rhythm: { name: "Двигаться", full_version: "30 минут", minimum_version: "5 минут" } }
    end
    rhythm = @user.rhythms.last
    assert_redirected_to rhythms_path

    patch rhythm_path(rhythm), params: { rhythm: { name: "Двигаться мягко", full_version: "30 минут", minimum_version: "5 минут" } }
    assert_redirected_to rhythms_path
    get rhythms_path
    assert_includes response.body, "Двигаться мягко"
  end

  test "today uses owner timezone and check-in persists across refresh" do
    @user.update!(timezone: "America/Los_Angeles")
    rhythm = @user.rhythms.create!(name: "Ритм", full_version: "Полная", minimum_version: "Минимум")

    travel_to Time.utc(2026, 8, 2, 6, 30) do
      post checkin_rhythm_path(rhythm), params: { state: "minimum" }
      assert_redirected_to rhythms_path
      assert_equal Date.new(2026, 8, 1), rhythm.rhythm_checkins.last.local_date
      get rhythms_path
    end
    assert_select "[data-rhythm-checkin='minimum']", minimum: 1
  end

  test "skipped day exposes explicit return and records it" do
    rhythm = @user.rhythms.create!(name: "Ритм", full_version: "Полная", minimum_version: "Минимум")
    post checkin_rhythm_path(rhythm), params: { state: "skipped" }
    get rhythms_path
    assert_select "form[action='#{return_rhythm_path(rhythm)}']", count: 1

    post return_rhythm_path(rhythm)
    assert_redirected_to rhythms_path
    assert_equal "returned", rhythm.rhythm_checkins.last.reload.state
    assert_equal "skipped", rhythm.rhythm_checkins.last.previous_state
  end

  test "foreign user cannot edit or check in another owner's rhythm" do
    foreign = users(:moscow_user).rhythms.create!(name: "Чужой", full_version: "Полная", minimum_version: "Минимум")

    patch rhythm_path(foreign), params: { rhythm: { name: "Украден", full_version: "x", minimum_version: "y" } }
    assert_redirected_to rhythms_path
    post checkin_rhythm_path(foreign), params: { state: "full" }
    assert_redirected_to rhythms_path
    assert_equal "Чужой", foreign.reload.name
    assert_empty foreign.rhythm_checkins
  end

  test "home exposes persisted rhythm depth while Plan stays calendar-first" do
    rhythm = @user.rhythms.create!(name: "Мой ритм", full_version: "Полная", minimum_version: "Минимум")
    rhythm.rhythm_checkins.create!(local_date: Time.current.in_time_zone(@user.timezone).to_date, state: "full")

    get calendar_events_path(view: "week")
    assert_select "[data-rhythm-plan]", count: 0
    get dashboard_path
    assert_select "[data-rhythm-home]", text: /Мой ритм.*полностью/m
    assert_select "[data-rhythm-home]", text: /Сегодня: full/, count: 0
  end

  test "return on the next owner-local day preserves the skipped day and provenance" do
    rhythm = @user.rhythms.create!(name: "Утро", full_version: "Прогулка", minimum_version: "Вода")
    zone = Time.find_zone!(@user.timezone)

    travel_to zone.local(2026, 8, 3, 20) do
      post checkin_rhythm_path(rhythm), params: { state: "skipped" }
    end
    travel_to zone.local(2026, 8, 4, 8) do
      get rhythms_path
      assert_select "form[action='#{return_rhythm_path(rhythm)}']", count: 1
      post return_rhythm_path(rhythm)
    end

    assert_equal "skipped", rhythm.rhythm_checkins.find_by!(local_date: Date.new(2026, 8, 3)).state
    returned = rhythm.rhythm_checkins.find_by!(local_date: Date.new(2026, 8, 4))
    assert_equal "returned", returned.state
    assert_equal "skipped", returned.previous_state
    assert returned.returned_at.present?

    assert_no_changes -> { returned.reload.attributes } do
      travel_to zone.local(2026, 8, 4, 9) do
        post checkin_rhythm_path(rhythm), params: { state: "full" }
      end
    end
  end
end

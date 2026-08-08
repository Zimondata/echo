require "test_helper"

class RhythmMonthMapTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @user.update!(timezone: "Europe/Madrid")
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    @rhythm = @user.rhythms.create!(
      name: "Тренировка",
      minimum_version: "Разминка",
      full_version: "Полная тренировка",
      position: 0
    )
  end

  test "renders only the selected month with neutral counts and navigation" do
    create_checkin("2026-07-31", "full")
    create_checkin("2026-08-01", "full")
    create_checkin("2026-08-02", "minimum")
    create_checkin("2026-08-03", "skipped")
    create_checkin("2026-08-04", "returned")
    create_checkin("2026-09-01", "full")

    get rhythms_path(month: "2026-08")

    assert_response :success
    assert_select "[data-rhythm-month='2026-08']"
    assert_select "a[href='#{rhythms_path(month: "2026-07")}']", text: /Назад/
    assert_select "a[href='#{rhythms_path(month: "2026-09")}']", text: /Вперёд/
    assert_select "[data-rhythm-id='#{@rhythm.id}']" do
      assert_select "[data-rhythm-day='2026-08-01'][data-rhythm-state='full']"
      assert_select "[data-rhythm-day='2026-08-02'][data-rhythm-state='minimum']"
      assert_select "[data-rhythm-day='2026-08-03'][data-rhythm-state='skipped']"
      assert_select "[data-rhythm-day='2026-08-04'][data-rhythm-state='returned']"
      assert_select "[data-rhythm-day='2026-07-31']", count: 0
      assert_select "[data-rhythm-day='2026-09-01']", count: 0
      assert_select "[data-state-count='full']", text: /1/
      assert_select "[data-state-count='minimum']", text: /1/
      assert_select "[data-state-count='skipped']", text: /1/
      assert_select "[data-state-count='returned']", text: /1/
    end
    assert_match(/возвращения после пропуска/i, response.body)
    assert_no_match(/streak|серия|процент|средн/i, response.body)
  end

  test "invalid month falls back to the owner current month" do
    travel_to Time.utc(2026, 8, 31, 22, 30) do
      get rhythms_path(month: "2026-99")
      assert_response :success
      assert_select "[data-rhythm-month='2026-09']"
    end
  end

  test "blank days remain blank recorded-event cells" do
    get rhythms_path(month: "2026-08")

    assert_select "[data-rhythm-id='#{@rhythm.id}'] [data-rhythm-day='2026-08-15'][data-rhythm-state='blank']"
    assert_match(/карта записанных событий/i, response.body)
  end

  test "rhythm checkin query count stays bounded as archived rhythms grow" do
    6.times do |index|
      rhythm = @user.rhythms.create!(
        name: "Архив #{index}",
        full_version: "Полностью",
        minimum_version: "Минимум",
        position: index + 10,
        active: false
      )
      rhythm.rhythm_checkins.create!(local_date: Date.new(2026, 8, index + 10), state: "full")
    end

    checkin_queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      if payload[:sql].include?('FROM "rhythm_checkins"') && !payload[:cached]
        checkin_queries << payload[:sql]
      end
    end

    get rhythms_path(month: "2026-08")

    assert_response :success
    assert_operator checkin_queries.size, :<=, 4
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  private

  def create_checkin(date, state)
    @rhythm.rhythm_checkins.create!(local_date: Date.iso8601(date), state: state)
  end
end

require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth = TelegramAuthSession.create!
    auth.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth.session_token }
    assert_response :success
    @user.nutrition_entries.delete_all
    @user.activity_entries.delete_all
  end

  test "empty overview is honest and never invokes the analyzer" do
    analyzer = Ai::DailyHealthAnalyzer.method(:analyze_day)
    Ai::DailyHealthAnalyzer.define_singleton_method(:analyze_day) { |*| raise "analyzer must not be called" }
    begin
      get health_path
    ensure
      Ai::DailyHealthAnalyzer.define_singleton_method(:analyze_day, analyzer)
    end

    assert_response :success
    assert_select "[data-health-empty]", text: "Нет данных", minimum: 2
    assert_includes response.body, "августа"
    assert_not_includes response.body, "August"
    assert_no_match(/0\s*(ккал|км|мин)|score|предупрежден|достижен|рекомендац/i, response.body)
  end

  test "overview reports only recorded owner values and preserves unknown activity fields" do
    zone = Time.find_zone!(@user.timezone)
    @user.nutrition_entries.create!(meal_type: "dinner", calories: 640, protein: 30, fat: 20, carbs: 70, recorded_at: zone.local(2026, 8, 3, 20))
    @user.activity_entries.create!(activity_type: "walking", duration_minutes: 35, distance_km: nil, calories_burned: nil, activity_date: zone.local(2026, 8, 3, 18), status: "active")
    foreign = users(:moscow_user)
    foreign.nutrition_entries.create!(meal_type: "lunch", calories: 999, protein: 1, fat: 1, carbs: 1, recorded_at: zone.local(2026, 8, 3, 12))

    travel_to zone.local(2026, 8, 3, 21) do
      get health_path
    end

    assert_response :success
    assert_includes response.body, "640"
    assert_includes response.body, "35 мин"
    assert_not_includes response.body, "999"
    assert_select "[data-activity-distance]", text: "Нет данных"
    assert_select "[data-activity-calories]", text: "Нет данных"
  end

  test "birthday nutrition flow parses owner wall time and returns to safe Health" do
    @user.update!(timezone: "Europe/Madrid")
    zone = Time.find_zone!(@user.timezone)
    analyzer = Ai::DailyHealthAnalyzer.method(:analyze_day)
    Ai::DailyHealthAnalyzer.define_singleton_method(:analyze_day) { |*| raise "safe Health flow must not call analyzer" }

    begin
      travel_to zone.local(2026, 8, 3, 23, 50) do
        assert_difference "@user.nutrition_entries.count", 1 do
          post health_nutrition_path, params: {
            nutrition_entry: {
              meal_type: "dinner", meal_description: "Поздний ужин", recorded_at: "2026-08-03T23:45",
              calories: 640, protein: 30, fat: 20, carbs: 70
            }
          }
        end

        assert_redirected_to health_path
        entry = @user.nutrition_entries.order(:id).last
        assert_equal zone.local(2026, 8, 3, 23, 45), entry.recorded_at
        assert_no_enqueued_jobs { follow_redirect! }
        assert_response :success
        assert_includes response.body, "Поздний ужин"
      end
    ensure
      Ai::DailyHealthAnalyzer.define_singleton_method(:analyze_day, analyzer)
    end
  end

  test "birthday activity flow parses owner wall time and returns to safe Health" do
    @user.update!(timezone: "Europe/Madrid")
    zone = Time.find_zone!(@user.timezone)

    travel_to zone.local(2026, 8, 4, 0, 20) do
      assert_difference "@user.activity_entries.count", 1 do
        post health_activity_path, params: {
          activity_entry: {
            activity_type: "walking", duration_minutes: 35, activity_date: "2026-08-04T00:15", notes: "Ночная прогулка"
          }
        }
      end

      assert_redirected_to health_path
      entry = @user.activity_entries.order(:id).last
      assert_equal zone.local(2026, 8, 4, 0, 15), entry.activity_date
      follow_redirect!
      assert_response :success
      assert_includes response.body, "Ночная прогулка"
    end
  end

  test "birthday Health rejects a nonexistent owner-local wall time" do
    @user.update!(timezone: "Europe/Madrid")

    assert_no_difference "@user.activity_entries.count" do
      post health_activity_path, params: {
        activity_entry: {
          activity_type: "walking", duration_minutes: 20, activity_date: "2026-03-29T02:30"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "не существует"
  end
end

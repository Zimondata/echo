require "test_helper"

class Api::V1::CalendarEventsAuthenticationTest < ActionController::TestCase
  tests Api::V1::CalendarEventsController

  setup do
    @owner = users(:john)
    @other = users(:utc_user)
    @foreign_event = @other.calendar_events.create!(
      title: "Private event",
      start_time: 1.hour.from_now,
      end_time: 2.hours.from_now,
      event_type: "meeting",
      priority: "medium"
    )
  end

  test "user_id parameter cannot authenticate a request" do
    get :index, params: { user_id: @other.id }, format: :json

    assert_response :unauthorized
    assert_equal "Authentication required", JSON.parse(response.body)["error"]
  end

  test "authenticated user cannot read another user's event" do
    session[:user_id] = @owner.id

    get :show, params: { id: @foreign_event.id, user_id: @other.id }, format: :json

    assert_response :not_found
  end
end

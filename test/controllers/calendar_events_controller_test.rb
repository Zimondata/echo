require "test_helper"

class CalendarEventsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get calendar_events_index_url
    assert_response :success
  end
end

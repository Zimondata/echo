require "test_helper"

class ApplicationControllerTest < ActiveSupport::TestCase
  setup do
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = users(:john).telegram_id.to_s
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "owner user check fails closed for any other account" do
    controller = ApplicationController.new

    assert controller.send(:owner_user?, users(:john))
    refute controller.send(:owner_user?, users(:moscow_user))
    refute controller.send(:owner_user?, nil)
  end
end

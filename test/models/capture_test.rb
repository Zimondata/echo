require "test_helper"

class CaptureTest < ActiveSupport::TestCase
  test "persists an immutable source record" do
    capture = Capture.create!(
      user: users(:john),
      source_type: "telegram_voice",
      source_ref: "telegram:123:456",
      idempotency_key: "telegram:123:456",
      raw_text: "Напомни завтра позвонить Лёхе",
      transcript: "Напомни завтра позвонить Лёхе",
      occurred_at: Time.zone.parse("2026-07-29 09:00")
    )

    assert capture.persisted?
    assert_equal "received", capture.status

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      capture.update!(raw_text: "переписанный исходник")
    end
  end
end

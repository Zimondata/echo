require "test_helper"

class RhythmTest < ActiveSupport::TestCase
  test "requires owner content and allows no more than three active rhythms" do
    user = users(:john)
    3.times { |index| user.rhythms.create!(name: "Ритм #{index}", full_version: "Полная #{index}", minimum_version: "Минимум #{index}", position: index) }

    fourth = user.rhythms.new(name: "Четвёртый", full_version: "Полная", minimum_version: "Минимум")
    assert_not fourth.valid?
    assert_includes fourth.errors[:base], "Можно иметь не больше трёх активных ритмов"

    inactive = user.rhythms.create!(name: "Архивный", full_version: "Полная", minimum_version: "Минимум", active: false)
    assert_predicate inactive, :persisted?
  end

  test "check-in validates state and is unique per rhythm and local date" do
    rhythm = users(:john).rhythms.create!(name: "Ритм", full_version: "Полная", minimum_version: "Минимум")
    rhythm.rhythm_checkins.create!(local_date: Date.new(2026, 8, 1), state: "full")

    duplicate = rhythm.rhythm_checkins.new(local_date: Date.new(2026, 8, 1), state: "unknown")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:state], "is not included in the list"
    assert_includes duplicate.errors[:local_date], "has already been taken"
  end

  test "skipped to returned preserves transition semantics" do
    rhythm = users(:john).rhythms.create!(name: "Ритм", full_version: "Полная", minimum_version: "Минимум")
    checkin = rhythm.rhythm_checkins.create!(local_date: Date.new(2026, 8, 1), state: "skipped")

    checkin.return!

    assert_equal "returned", checkin.reload.state
    assert_equal "skipped", checkin.previous_state
    assert_not_nil checkin.returned_at
  end
end

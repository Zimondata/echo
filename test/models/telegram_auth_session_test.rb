require "test_helper"

class TelegramAuthSessionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    TelegramAuthSession.delete_all
    @user = users(:john)
    @previous_owner_id = ENV["ECHO_OWNER_TELEGRAM_ID"]
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @user.telegram_id.to_s
  end

  teardown do
    ENV["ECHO_OWNER_TELEGRAM_ID"] = @previous_owner_id
  end

  test "consume_confirmed atomically expires a valid confirmed session" do
    auth_session = TelegramAuthSession.create!(
      user: @user,
      telegram_id: @user.telegram_id,
      status: "confirmed",
      confirmed_at: Time.current,
      expires_at: 5.minutes.from_now
    )

    consumed = TelegramAuthSession.consume_confirmed(auth_session.session_token)

    assert_equal auth_session.id, consumed.id
    assert_equal "expired", auth_session.reload.status
    assert_nil TelegramAuthSession.consume_confirmed(auth_session.session_token)
  end

  test "consume_confirmed rejects an expired confirmed session" do
    auth_session = TelegramAuthSession.create!(
      user: @user,
      telegram_id: @user.telegram_id,
      status: "confirmed",
      confirmed_at: 10.minutes.ago,
      expires_at: 1.minute.ago
    )

    assert_nil TelegramAuthSession.consume_confirmed(auth_session.session_token)
    assert_equal "confirmed", auth_session.reload.status
  end

  test "consume_confirmed allows exactly one concurrent success" do
    auth_session = TelegramAuthSession.create!(
      user: @user,
      telegram_id: @user.telegram_id,
      status: "confirmed",
      confirmed_at: Time.current,
      expires_at: 5.minutes.from_now
    )
    barrier = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          TelegramAuthSession.consume_confirmed(auth_session.session_token)&.id
        rescue ActiveRecord::StatementInvalid => e
          e
        end
      end
    end
    2.times { barrier << true }
    results = threads.map(&:value)

    assert_equal 1, results.count(auth_session.id)
    assert_equal 1, results.count(nil)
    refute results.any? { |result| result.is_a?(Exception) }
  end

  test "confirm rejects a stale second claimant" do
    auth_session = TelegramAuthSession.create!
    stale_copy = TelegramAuthSession.find(auth_session.id)

    auth_session.confirm!(@user)

    assert_raises(ActiveRecord::RecordNotSaved) do
      stale_copy.confirm!(@user)
    end
    assert_equal "confirmed", stale_copy.reload.status
  end
end

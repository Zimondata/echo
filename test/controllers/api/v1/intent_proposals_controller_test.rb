require "test_helper"

class Api::V1::IntentProposalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    _credential, raw_token = EchoServiceToken.issue!(
      user: @user,
      name: "Intent review trusted test bridge",
      scopes: [ "echo:trusted" ]
    )
    @trusted_headers = { "Authorization" => "Bearer #{raw_token}" }

    @capture = @user.captures.create!(
      source_type: "telegram_voice",
      source_ref: "telegram:123:review-test",
      idempotency_key: "telegram:123:review-test",
      transcript: "Попроси Гэри проверить лендинг",
      occurred_at: Time.current,
      status: "needs_review"
    )
    @proposal = @capture.intent_proposals.create!(
      intent_type: "agent_action",
      title: "Проверить лендинг",
      owner_type: "gary",
      risk_level: "confirm",
      confidence: 0.91,
      source_span: { start: 0, end: 31 }
    )
  end

  test "machine token cannot perform the human proposal review" do
    patch "/api/v1/intent_proposals/#{@proposal.id}/review", params: {
      decision: "accept",
      proposal: {
        title: "Проверить мобильный лендинг",
        due_at: "2026-07-30T12:00:00+02:00"
      }
    }, headers: @trusted_headers, as: :json

    assert_response :not_found
    @proposal.reload
    @capture.reload

    assert_equal "Проверить лендинг", @proposal.title
    assert_equal "proposed", @proposal.status
    assert_equal({ "start" => 0, "end" => 31 }, @proposal.source_span)
    assert_equal "needs_review", @capture.status
  end
end

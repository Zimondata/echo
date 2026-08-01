require "test_helper"

class Api::V1::CapturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    assert_response :success
    _credential, raw_token = EchoServiceToken.issue!(
      user: @user,
      name: "Default trusted test bridge",
      scopes: [ "echo:trusted" ]
    )
    @trusted_headers = { "Authorization" => "Bearer #{raw_token}" }
  end

  test "does not trust a caller supplied user id" do
    reset!

    post "/api/v1/captures", params: {
      user_id: @user.id,
      capture: {
        source_type: "telegram_text",
        source_ref: "telegram:123:forged",
        idempotency_key: "telegram:123:forged",
        raw_text: "forged",
        occurred_at: Time.current.iso8601
      }
    }, as: :json

    assert_response :unauthorized
  end

  test "accepts a scoped Hermes service token without trusting user parameters" do
    reset!
    _credential, raw_token = EchoServiceToken.issue!(
      user: @user,
      name: "Hermes test bridge",
      scopes: [ "echo:trusted" ]
    )

    post "/api/v1/captures", params: {
      capture: {
        source_type: "telegram_text",
        source_ref: "telegram:123:service-token",
        idempotency_key: "telegram:123:service-token",
        raw_text: "Проверить Echo",
        occurred_at: Time.current.iso8601
      }
    }, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json

    assert_response :created
    assert_equal @user.id, Capture.last.user_id
  end

  test "rejects a browser session without a trusted service token" do
    post "/api/v1/captures", params: {
      capture: {
        source_type: "telegram_text",
        source_ref: "telegram:123:session-only",
        idempotency_key: "telegram:123:session-only",
        raw_text: "session must not authorize trusted API",
        occurred_at: Time.current.iso8601
      }
    }, as: :json

    assert_response :unauthorized
    assert_not Capture.exists?(source_ref: "telegram:123:session-only")
  end

  test "service token principal wins even when another browser session exists" do
    token_user = users(:utc_user)
    _credential, raw_token = EchoServiceToken.issue!(
      user: token_user,
      name: "Cross-principal test bridge",
      scopes: [ "echo:trusted" ]
    )

    post "/api/v1/captures", params: {
      capture: {
        source_type: "telegram_text",
        source_ref: "telegram:123:token-principal",
        idempotency_key: "telegram:123:token-principal",
        raw_text: "token owns this capture",
        occurred_at: Time.current.iso8601
      }
    }, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json

    assert_response :created
    assert_equal token_user.id, Capture.last.user_id
  end

  test "creates one capture with typed proposals and deduplicates retries" do
    payload = {
      capture: {
        source_type: "telegram_voice",
        source_ref: "telegram:123:api-456",
        idempotency_key: "telegram:123:api-456",
        transcript: "Завтра позвони Лёхе и попроси Гэри проверить лендинг",
        occurred_at: "2026-07-29T09:00:00+02:00",
        intent_proposals: [
          {
            intent_type: "task",
            title: "Позвонить Лёхе",
            owner_type: "user",
            risk_level: "reversible",
            confidence: 0.96,
            source_span: { start: 7, end: 20 }
          },
          {
            intent_type: "agent_action",
            title: "Проверить лендинг",
            owner_type: "gary",
            risk_level: "confirm",
            confidence: 0.91,
            source_span: { start: 23, end: 55 }
          }
        ]
      }
    }

    assert_difference({ -> { Capture.count } => 1, -> { IntentProposal.count } => 2 }) do
      post "/api/v1/captures", params: payload, headers: @trusted_headers, as: :json
    end

    assert_response :created
    body = response.parsed_body.fetch("data")
    assert_equal "needs_review", body.fetch("status")
    assert_equal 2, body.fetch("intent_proposals").size

    assert_no_difference [ "Capture.count", "IntentProposal.count" ] do
      post "/api/v1/captures", params: payload, headers: @trusted_headers, as: :json
    end

    assert_response :success
    assert_equal true, response.parsed_body.fetch("data").fetch("deduplicated")
  end
end

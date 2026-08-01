require "test_helper"

class Api::V1::AgentRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }
    _credential, raw_token = EchoServiceToken.issue!(
      user: @user,
      name: "Agent run trusted test bridge",
      scopes: [ "echo:trusted" ]
    )
    @trusted_headers = { "Authorization" => "Bearer #{raw_token}" }
    _verifier, verifier_token = EchoServiceToken.issue!(
      user: @user,
      name: "Independent evidence verifier",
      scopes: [ "evidence:verify" ]
    )
    @verifier_headers = { "Authorization" => "Bearer #{verifier_token}" }

    capture = @user.captures.create!(
      source_type: "telegram_voice",
      source_ref: "telegram:123:agent-api",
      idempotency_key: "telegram:123:agent-api",
      transcript: "Попроси Гэри проверить мобильный Echo",
      occurred_at: Time.current,
      status: "ready"
    )
    @proposal = capture.intent_proposals.create!(
      intent_type: "agent_action",
      title: "Проверить мобильный Echo",
      owner_type: "gary",
      risk_level: "confirm",
      source_span: { start: 0, end: 37 },
      status: "accepted"
    )
  end

  test "runs an approved action and closes it only with evidence" do
    assert_difference({ -> { AgentRun.count } => 1, -> { ApprovalRequest.count } => 1 }) do
      post "/api/v1/agent_runs", params: {
        agent_run: {
          intent_proposal_id: @proposal.id,
          objective: "Проверить мобильный Echo",
          definition_of_done: "Нет горизонтального overflow на ширине 390px"
        }
      }, headers: @trusted_headers, as: :json
    end

    assert_response :created
    run = AgentRun.last
    approval = run.approval_requests.last
    assert_equal "waiting_approval", run.status

    patch "/api/v1/approval_requests/#{approval.id}/resolve", params: { decision: "approve" }, headers: @trusted_headers, as: :json
    assert_response :not_found
    assert_equal "pending", approval.reload.status

    patch "/api/v1/agent_runs/#{run.id}/transition", params: { action_name: "start" }, headers: @trusted_headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "waiting_approval", run.reload.status

    patch "/inbox/approval_requests/#{approval.id}/resolve", params: {
      decision: "approve",
      decision_note: "Запускай"
    }, as: :json
    assert_response :success
    assert_equal "queued", run.reload.status

    patch "/api/v1/agent_runs/#{run.id}/transition", params: { action_name: "start" }, headers: @trusted_headers, as: :json
    assert_response :success
    assert_equal "running", run.reload.status

    post "/api/v1/agent_runs/#{run.id}/evidence_receipts", params: {
      evidence_receipt: {
        receipt_type: "browser_check",
        summary: "Mobile viewport passed",
        target_ref: "http://127.0.0.1:4322",
        verification: "scrollWidth=390 innerWidth=390",
        verified: true,
        occurred_at: Time.current.iso8601
      }
    }, headers: @trusted_headers, as: :json
    assert_response :created

    receipt = run.evidence_receipts.last
    assert_not receipt.verified, "caller must not be able to self-verify evidence"

    patch "/api/v1/agent_runs/#{run.id}/transition", params: { action_name: "succeed" }, headers: @trusted_headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "running", run.reload.status

    patch "/api/v1/evidence_receipts/#{receipt.id}/verify", headers: @trusted_headers, as: :json
    assert_response :unauthorized
    assert_not receipt.reload.verified

    patch "/api/v1/evidence_receipts/#{receipt.id}/verify", headers: @verifier_headers, as: :json
    assert_response :success
    assert receipt.reload.verified
    assert_equal "Independent evidence verifier", receipt.metadata["verifier"]

    patch "/api/v1/agent_runs/#{run.id}/transition", params: { action_name: "succeed" }, headers: @trusted_headers, as: :json
    assert_response :success
    assert_equal "succeeded", run.reload.status
  end

  test "expired approval is atomically expired and returns conflict" do
    post "/api/v1/agent_runs", params: {
      agent_run: {
        intent_proposal_id: @proposal.id,
        objective: "Проверить мобильный Echo",
        definition_of_done: "Есть evidence"
      }
    }, headers: @trusted_headers, as: :json
    approval = AgentRun.last.approval_requests.last

    travel_to approval.expires_at + 1.second do
      patch "/inbox/approval_requests/#{approval.id}/resolve", params: { decision: "approve" }, as: :json
    end

    assert_response :conflict
    assert_equal "expired", approval.reload.status
    assert_equal "cancelled", approval.agent_run.reload.status
  end

  test "approval cannot authorize a mutated proposal payload" do
    post "/api/v1/agent_runs", params: {
      agent_run: {
        intent_proposal_id: @proposal.id,
        objective: "Проверить мобильный Echo",
        definition_of_done: "Есть evidence"
      }
    }, headers: @trusted_headers, as: :json
    approval = AgentRun.last.approval_requests.last
    @proposal.update_column(:payload, { "target" => "changed-after-approval" })

    patch "/inbox/approval_requests/#{approval.id}/resolve", params: { decision: "approve" }, as: :json

    assert_response :conflict
    assert_equal "cancelled", approval.reload.status
    assert_equal "cancelled", approval.agent_run.reload.status
  end
end

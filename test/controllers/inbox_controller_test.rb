require "test_helper"

class InboxControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    auth_session = TelegramAuthSession.create!
    auth_session.confirm!(@user)
    post "/sessions/complete_telegram_auth", params: { session_token: auth_session.session_token }

    capture = @user.captures.create!(
      source_type: "telegram_voice",
      source_ref: "telegram:123:inbox-ui",
      idempotency_key: "telegram:123:inbox-ui",
      transcript: "Завтра позвони Лёхе и попроси Гэри проверить лендинг",
      occurred_at: Time.current,
      status: "needs_review"
    )
    @user_proposal = capture.intent_proposals.create!(
      intent_type: "task",
      title: "Позвонить Лёхе",
      owner_type: "user",
      risk_level: "reversible",
      confidence: 0.96,
      source_span: { start: 7, end: 20 }
    )
    @gary_proposal = capture.intent_proposals.create!(
      intent_type: "agent_action",
      title: "Проверить лендинг",
      owner_type: "gary",
      risk_level: "confirm",
      confidence: 0.91,
      source_span: { start: 23, end: 55 }
    )
  end

  test "shows transcript provenance and separates user work from Gary work" do
    get "/inbox"

    assert_response :success
    assert_select "h1", text: "Входящие"
    assert_select "[data-capture-transcript]", text: /Завтра позвони Лёхе/
    assert_select "[data-owner='user']", text: /Мне/
    assert_select "[data-owner='gary']", text: /Gary/
    assert_select "button[data-review-decision='accept']", minimum: 2
    assert_select "button[data-review-decision='reject']", minimum: 2
  end

  test "browser session reviews its own proposal without a service token" do
    patch "/inbox/intent_proposals/#{@user_proposal.id}/review", params: { decision: "accept" }, as: :json

    assert_response :success
    assert_equal "accepted", @user_proposal.reload.status
  end

  test "browser session cannot review another user's proposal" do
    other = users(:utc_user)
    capture = other.captures.create!(
      source_type: "manual", source_ref: SecureRandom.uuid,
      idempotency_key: SecureRandom.uuid, occurred_at: Time.current, status: "needs_review"
    )
    proposal = capture.intent_proposals.create!(
      intent_type: "task", title: "Чужая задача", owner_type: "user",
      risk_level: "reversible", source_span: { start: 0, end: 1 }
    )

    patch "/inbox/intent_proposals/#{proposal.id}/review", params: { decision: "accept" }, as: :json

    assert_response :not_found
    assert_equal "proposed", proposal.reload.status
  end

  test "browser session resolves its own approval" do
    @gary_proposal.update!(status: "accepted")
    run = @user.agent_runs.create!(
      intent_proposal: @gary_proposal, objective: "Проверить лендинг",
      definition_of_done: "Есть отчёт", executor: "gary", status: "waiting_approval"
    )
    approval = run.approval_requests.create!(risk_reason: "Внешнее действие", requested_at: Time.current)

    patch "/inbox/approval_requests/#{approval.id}/resolve", params: { decision: "approve" }, as: :json

    assert_response :success
    assert_equal "approved", approval.reload.status
    assert_equal "queued", run.reload.status
    assert_equal "user:#{@user.id}", approval.decided_by
  end
end

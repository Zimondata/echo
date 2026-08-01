require "test_helper"

class AgentRunTest < ActiveSupport::TestCase
  setup do
    capture = Capture.create!(
      user: users(:john),
      source_type: "telegram_voice",
      source_ref: "telegram:123:agent-run-test",
      idempotency_key: "telegram:123:agent-run-test",
      transcript: "Попроси Гэри проверить лендинг",
      occurred_at: Time.current
    )
    @proposal = capture.intent_proposals.create!(
      intent_type: "agent_action",
      title: "Проверить лендинг",
      owner_type: "gary",
      risk_level: "confirm",
      source_span: { start: 0, end: 31 },
      status: "accepted"
    )
  end

  test "cannot start while approval is still pending" do
    run = AgentRun.create!(
      user: users(:john),
      intent_proposal: @proposal,
      objective: "Отправить внешнее сообщение",
      definition_of_done: "Есть внешний message id",
      status: "waiting_approval",
      approval_required: true
    )

    assert_raises(AgentRun::InvalidTransitionError) { run.start! }
    assert_equal "waiting_approval", run.reload.status
  end

  test "cannot report success without verified evidence" do
    run = AgentRun.create!(
      user: users(:john),
      intent_proposal: @proposal,
      objective: "Проверить мобильный Echo",
      definition_of_done: "Страница открывается на 390px без overflow"
    )

    run.start!
    assert_equal "running", run.status

    assert_raises(AgentRun::MissingEvidenceError) { run.succeed! }

    run.evidence_receipts.create!(
      receipt_type: "browser_check",
      summary: "Mobile viewport passed",
      target_ref: "http://127.0.0.1:4322",
      verification: "scrollWidth=390 innerWidth=390",
      verified: true,
      occurred_at: Time.current
    )
    run.succeed!

    assert_equal "succeeded", run.status
    assert run.finished_at.present?
  end
end

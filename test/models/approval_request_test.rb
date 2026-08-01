require "test_helper"

class ApprovalRequestTest < ActiveSupport::TestCase
  setup do
    capture = Capture.create!(
      user: users(:john),
      source_type: "telegram_voice",
      source_ref: "telegram:123:approval-test",
      idempotency_key: "telegram:123:approval-test",
      transcript: "Попроси Гэри отправить письмо",
      occurred_at: Time.current
    )
    proposal = capture.intent_proposals.create!(
      intent_type: "agent_action",
      title: "Отправить письмо",
      owner_type: "gary",
      risk_level: "confirm",
      source_span: { start: 0, end: 29 },
      status: "accepted"
    )
    @run = AgentRun.create!(
      user: users(:john),
      intent_proposal: proposal,
      objective: "Отправить письмо",
      definition_of_done: "Получен внешний message id",
      approval_required: true,
      status: "waiting_approval"
    )
  end

  test "approval releases a waiting agent run" do
    approval = @run.approval_requests.create!(
      risk_reason: "Внешнее сообщение от лица пользователя",
      requested_at: Time.current
    )

    approval.approve!(decided_by: "user")

    assert_equal "approved", approval.status
    assert approval.resolved_at.present?
    assert_equal "queued", @run.reload.status
    assert_raises(ApprovalRequest::AlreadyResolvedError) do
      approval.approve!(decided_by: "user")
    end
  end
end

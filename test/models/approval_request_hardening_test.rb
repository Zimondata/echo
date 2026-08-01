require "test_helper"

class ApprovalRequestHardeningTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @capture = Capture.create!(
      user: @user,
      source_type: "manual",
      source_ref: "approval-hardening-#{SecureRandom.uuid}",
      idempotency_key: SecureRandom.uuid,
      occurred_at: Time.current,
      status: "parsed"
    )
    @proposal = @capture.intent_proposals.create!(
      title: "Опубликовать отчёт",
      intent_type: "agent_action",
      owner_type: "gary",
      risk_level: "confirm",
      status: "accepted",
      source_span: { "start" => 0, "end" => 1 },
      payload: { "channel" => "telegram", "text" => "draft" }
    )
    @run = @user.agent_runs.create!(
      intent_proposal: @proposal,
      objective: "Опубликовать отчёт",
      definition_of_done: "Сообщение отправлено",
      executor: "gary",
      status: "waiting_approval"
    )
    @approval = @run.approval_requests.create!(
      risk_reason: "Отправка наружу",
      requested_at: Time.current
    )
  end

  test "approval snapshots the exact action and expires" do
    original_payload = @approval.action_payload.deep_dup

    assert @approval.action_payload.present?
    assert_equal ApprovalRequest.digest_for(@approval.action_payload), @approval.payload_digest
    assert_operator @approval.expires_at, :>, @approval.requested_at

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      @approval.update!(action_payload: { "tampered" => true })
    end
    assert_equal original_payload, @approval.reload.action_payload
  end

  test "approval-bound action fields are immutable and out-of-band corruption fails closed" do
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      @run.update!(objective: "Опубликовать другой отчёт")
    end
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      @proposal.update!(payload: { "channel" => "email" })
    end
    @run.reload
    @proposal.reload

    # Simulate corruption that bypasses model callbacks; digest verification
    # must still cancel the approval and run.
    @run.update_column(:objective, "Опубликовать другой отчёт")

    assert_raises(ApprovalRequest::PayloadChangedError) do
      @approval.approve!(decided_by: "user")
    end

    assert_equal "cancelled", @approval.reload.status
    assert_equal "cancelled", @run.reload.status
  end

  test "mutation injected inside approval resolution cannot queue a changed action" do
    original_payload = @proposal.payload.deep_dup
    singleton = ApprovalRequest.singleton_class
    original = ApprovalRequest.method(:action_payload_for)
    singleton.define_method(:action_payload_for) do |run|
      run.intent_proposal.update!(payload: { "channel" => "email" })
      original.call(run)
    end

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      @approval.approve!(decided_by: "user")
    end
  ensure
    singleton&.define_method(:action_payload_for) { |run| original.call(run) }

    assert_equal "pending", @approval.reload.status
    assert_equal "waiting_approval", @run.reload.status
    assert_equal original_payload, @proposal.reload.payload
  end

  test "expired approval cannot queue execution" do
    travel_to @approval.expires_at + 1.second do
      assert_raises(ApprovalRequest::ExpiredError) do
        @approval.approve!(decided_by: "user")
      end
    end

    assert_equal "expired", @approval.reload.status
    assert_equal "cancelled", @run.reload.status
  end

  test "unchanged approval queues the snapshotted run" do
    @approval.approve!(decided_by: "user", note: "Одобряю")

    assert_equal "approved", @approval.reload.status
    assert_equal "queued", @run.reload.status
  end
end

require "test_helper"

class IntentProposalTest < ActiveSupport::TestCase
  setup do
    @capture = Capture.create!(
      user: users(:john),
      source_type: "telegram_voice",
      source_ref: "telegram:123:proposal-test",
      idempotency_key: "telegram:123:proposal-test",
      transcript: "Завтра позвони Лёхе",
      occurred_at: Time.current
    )
  end

  test "keeps a typed intent linked to its exact source span" do
    proposal = @capture.intent_proposals.create!(
      intent_type: "task",
      title: "Позвонить Лёхе",
      owner_type: "user",
      risk_level: "reversible",
      confidence: 0.94,
      source_span: { start: 7, end: 20 }
    )

    assert_equal "proposed", proposal.status
    assert_equal({ "start" => 7, "end" => 20 }, proposal.source_span)

    proposal.accept!

    assert_equal "accepted", proposal.status
    assert proposal.accepted_at.present?
  end

  test "rejects a source span with reversed bounds" do
    proposal = @capture.intent_proposals.build(
      intent_type: "task",
      title: "Позвонить Лёхе",
      owner_type: "user",
      risk_level: "reversible",
      confidence: 0.94,
      source_span: { start: 20, end: 7 }
    )

    assert_not proposal.valid?
    assert_includes proposal.errors[:source_span], "must point to an ordered source range"
  end
end

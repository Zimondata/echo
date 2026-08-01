require "digest"

class ApprovalRequest < ApplicationRecord
  class AlreadyResolvedError < StandardError; end
  class ExpiredError < StandardError; end
  class PayloadChangedError < StandardError; end

  STATUSES = %w[pending approved rejected expired cancelled].freeze

  belongs_to :agent_run

  attr_readonly :action_payload, :payload_digest, :expires_at

  validates :status, inclusion: { in: STATUSES }
  validates :risk_reason, :requested_at, :expires_at, :payload_digest, presence: true
  validates :action_payload, presence: true

  before_validation :snapshot_action, on: :create

  def approve!(decided_by:, note: nil)
    resolve!(status: "approved", decided_by: decided_by, note: note)
  end

  def reject!(decided_by:, note: nil)
    resolve!(status: "rejected", decided_by: decided_by, note: note)
  end

  def self.action_payload_for(run)
    proposal = run.intent_proposal
    {
      "agent_run" => {
        "intent_proposal_id" => run.intent_proposal_id,
        "objective" => run.objective,
        "definition_of_done" => run.definition_of_done,
        "executor" => run.executor
      },
      "proposal" => {
        "title" => proposal.title,
        "owner_type" => proposal.owner_type,
        "risk_level" => proposal.risk_level,
        "payload" => proposal.payload || {}
      }
    }
  end

  def self.digest_for(payload)
    Digest::SHA256.hexdigest(JSON.generate(canonicalize(payload)))
  end

  def self.expire_stale_for!(user)
    joins(:agent_run)
      .where(agent_runs: { user_id: user.id }, status: "pending")
      .where("expires_at <= ?", Time.current)
      .find_each(&:expire!)
  end

  def expire!
    transaction do
      lock!
      expire_and_cancel_run! if pending? && expires_at <= Time.current
    end
    self
  end

  def self.canonicalize(value)
    case value
    when Hash
      value.keys.map(&:to_s).sort.to_h do |key|
        raw_value = value.key?(key) ? value[key] : value[key.to_sym]
        [ key, canonicalize(raw_value) ]
      end
    when Array
      value.map { |item| canonicalize(item) }
    else
      value
    end
  end

  private

  def snapshot_action
    self.requested_at ||= Time.current
    self.expires_at ||= requested_at + 24.hours
    self.action_payload = self.class.action_payload_for(agent_run)
    self.payload_digest = self.class.digest_for(action_payload)
  end

  def resolve!(status:, decided_by:, note:)
    outcome = nil

    transaction do
      # Fixed lock order prevents the approved action from changing between
      # digest verification and queueing: proposal -> run -> approval.
      # A failed attempt to mutate an approval-bound association can leave the
      # cached model dirty. Reload before locking so fail-closed verification
      # never turns that state into an unrelated RuntimeError/500.
      proposal = agent_run.intent_proposal.reload
      proposal.lock!
      run = agent_run.reload
      run.lock!
      lock!
      raise AlreadyResolvedError, "Approval request is already #{self.status}" unless pending?

      if expires_at <= Time.current
        expire_and_cancel_run!
        outcome = :expired
      elsif payload_digest != self.class.digest_for(self.class.action_payload_for(run))
        cancel_for_payload_change!
        outcome = :payload_changed
      else
        update!(
          status: status,
          resolved_at: Time.current,
          decided_by: decided_by,
          decision_note: note
        )
        if status == "approved"
          run.update!(status: "queued") if run.status == "waiting_approval"
        else
          cancel_run!
        end
      end
    end

    raise ExpiredError, "Approval request has expired" if outcome == :expired
    raise PayloadChangedError, "Approved action payload has changed" if outcome == :payload_changed

    self
  end

  def pending?
    status == "pending"
  end

  def expire_and_cancel_run!
    update!(status: "expired", resolved_at: Time.current, decision_note: "Expired before decision")
    cancel_run!
  end

  def cancel_for_payload_change!
    update!(status: "cancelled", resolved_at: Time.current, decision_note: "Action payload changed")
    cancel_run!
  end

  def cancel_run!
    agent_run.update!(status: "cancelled", finished_at: Time.current)
  end
end

require "digest"

class HardenApprovals < ActiveRecord::Migration[8.0]
  class ApprovalRow < ActiveRecord::Base
    self.table_name = "approval_requests"
  end

  class AgentRunRow < ActiveRecord::Base
    self.table_name = "agent_runs"
  end

  class ProposalRow < ActiveRecord::Base
    self.table_name = "intent_proposals"
  end

  def up
    add_column :approval_requests, :action_payload, :json, null: false, default: {}
    add_column :approval_requests, :payload_digest, :string
    add_column :approval_requests, :expires_at, :datetime
    add_index :approval_requests, :payload_digest
    add_index :approval_requests, [ :status, :expires_at ]

    ApprovalRow.reset_column_information
    ApprovalRow.find_each do |approval|
      run = AgentRunRow.find(approval.agent_run_id)
      proposal = ProposalRow.find(run.intent_proposal_id)
      payload = snapshot(run, proposal)
      approval.update_columns(
        action_payload: payload,
        payload_digest: digest(payload),
        expires_at: approval.requested_at + 24.hours
      )
    end

    change_column_null :approval_requests, :payload_digest, false
    change_column_null :approval_requests, :expires_at, false
  end

  def down
    remove_index :approval_requests, [ :status, :expires_at ]
    remove_index :approval_requests, :payload_digest
    remove_column :approval_requests, :expires_at
    remove_column :approval_requests, :payload_digest
    remove_column :approval_requests, :action_payload
  end

  private

  def snapshot(run, proposal)
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

  def digest(payload)
    Digest::SHA256.hexdigest(JSON.generate(canonicalize(payload)))
  end

  def canonicalize(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [ key, canonicalize(value[key]) ] }
    when Array
      value.map { |item| canonicalize(item) }
    else
      value
    end
  end
end
